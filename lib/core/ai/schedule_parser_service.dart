import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../config/app_config.dart';
import '../utils/time_utils.dart';
import 'offline_schedule_parser.dart';
import 'pdf_text_extractor.dart';

class ScheduleParserService {
  static const String _defaultPrompt = '''
You are an expert schedule extraction AI. Analyze the provided schedule image or document text (which could be a university class timetable, certificate of registration / matriculation / enrollment form, study load, work shift roster, hospital/security duty roster, or handwritten schedule).

Extract EVERY schedule event/shift without skipping any rows, subjects, lectures, or laboratory sessions. Output ONLY a valid JSON array matching this exact schema:
[
  {
    "title": "string (subject code, course name, job role, or duty description e.g. ITIAS2, IT SAM, Cashier Duty)",
    "category": "string (one of: 'class', 'work', 'duty', 'custom')",
    "daysOfWeek": [number (integers 1 to 7 where 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday)],
    "startTime": "string (24-hour format HH:mm e.g. 07:00, 08:30, 13:00, 17:00, 22:00)",
    "endTime": "string (24-hour format HH:mm e.g. 09:00, 10:00, 15:30, 19:00, 06:00)",
    "spansNextDay": boolean (true if shift crosses midnight e.g. 22:00 to 06:00, false otherwise),
    "location": "string or null (room number, venue, lab e.g. CLB 4, LAN LAB, Room 302)",
    "notes": "string or null (course description, professor/instructor name e.g. Information Assurance and Security 2 / Daryl Ivan Hisola)"
  }
]

Critical Extraction Rules:
1. Extract ALL entries on the document. Do NOT truncate or omit any course, lecture, laboratory session, or day (especially Thursday, Saturday, Sunday, Friday).
2. Separate Lecture and Lab entries into distinct items if they have different times/days (e.g. ITIAS2 Lecture on Thursday 5:00-7:00 PM and ITIAS2L Lab on Thursday 7:00-9:00 PM).
3. Resolve common Philippine and international university day abbreviations:
   - Monday: M, Mon -> [1]
   - Tuesday: T, Tu, Tue -> [2]
   - Wednesday: W, Wed -> [3]
   - Thursday: TH, Th, Thu, H, R, TR (if Thursday) -> [4]
   - Friday: F, Fri -> [5]
   - Saturday: S, Sa, Sat -> [6]
   - Sunday: SU, Su, Sun -> [7]
   - Combined days:
     - TTH / T-TH / T/TH / TR -> [2, 4] (Tuesday & Thursday)
     - MWF / M-W-F / M/W/F -> [1, 3, 5] (Monday, Wednesday, Friday)
     - MW / M-W -> [1, 3]
     - FS / F-S -> [5, 6]
     - SS / S-SU / Sat-Sun -> [6, 7]
4. Convert all 12-hour AM/PM times into 24-hour HH:mm format (e.g. 7:00 AM -> 07:00, 1:00 PM -> 13:00, 5:00 PM -> 17:00, 7:00 PM -> 19:00).
5. Output ONLY the raw JSON array. Do not include markdown codeblocks (no ```json).
''';

  /// Hybrid Multi-AI Cascade:
  /// Preferred Offline -> Next.js Server Proxy (/api/ai/parse) -> Groq LPU (Text for PDF CORs / Vision for Images)
  /// -> Google Gemini (Multimodal PDF & Image) -> OpenRouter -> Cloudflare Workers AI -> Fallback On-Device Offline
  Future<List<ScheduleEntry>> parseImage({
    required Uint8List imageBytes,
    required String mimeType,
    String? geminiApiKey,
    String? groqApiKey,
    String? openRouterApiKey,
    String? cloudflareAccountId,
    String? cloudflareApiToken,
    String preferredEngine = 'auto', // 'auto', 'offline', 'groq', 'gemini', 'openrouter', 'cloudflare'
  }) async {
    final bool isPdf = mimeType.toLowerCase().contains('pdf') ||
        PdfTextExtractor.isPdfBytes(imageBytes);
    final String extractedPdfText =
        isPdf ? PdfTextExtractor.extractText(imageBytes) : '';
    final bool hasDigitalPdfText = isPdf && extractedPdfText.trim().length >= 25;

    if (hasDigitalPdfText) {
      debugPrint(
        'ScheduleParserService: Direct PDF/COR text extracted (${extractedPdfText.length} chars). Zero-blur text mode enabled.',
      );
    }

    // 0. Explicit Offline Mode: On-Device ML Kit / Direct PDF Text Engine
    if (preferredEngine == 'offline') {
      debugPrint('ScheduleParserService: [Tier 0] Parsing via On-Device Local Offline Engine...');
      return await OfflineScheduleParser.parseFromBytes(
        imageBytes,
        mimeType: mimeType,
      );
    }

    final effectiveGeminiKey = (geminiApiKey != null && geminiApiKey.trim().isNotEmpty)
        ? geminiApiKey.trim()
        : AppConfig.defaultGeminiApiKey;

    final effectiveGroqKey = (groqApiKey != null && groqApiKey.trim().isNotEmpty)
        ? groqApiKey.trim()
        : AppConfig.defaultGroqApiKey;

    final effectiveOpenRouterKey = (openRouterApiKey != null && openRouterApiKey.trim().isNotEmpty)
        ? openRouterApiKey.trim()
        : AppConfig.defaultOpenRouterApiKey;

    final effectiveCfAccountId = (cloudflareAccountId != null && cloudflareAccountId.trim().isNotEmpty)
        ? cloudflareAccountId.trim()
        : AppConfig.cloudflareAccountId;

    final effectiveCfToken = (cloudflareApiToken != null && cloudflareApiToken.trim().isNotEmpty)
        ? cloudflareApiToken.trim()
        : AppConfig.cloudflareApiToken;

    String? rawJson;
    String lastError = '';

    // 0.5. Next.js Server Proxy Tier (/api/ai/parse) when configured & user is signed in
    final proxyUrl = AppConfig.aiProxyUrl;
    if (proxyUrl.isNotEmpty && preferredEngine == 'auto') {
      try {
        debugPrint('ScheduleParserService: [Tier 0.5] Attempting Next.js Server AI Proxy ($proxyUrl)...');
        rawJson = await _parseWithServerProxy(
          proxyUrl: proxyUrl,
          imageBytes: imageBytes,
          mimeType: mimeType,
          extractedText: hasDigitalPdfText ? extractedPdfText : null,
        );
      } catch (e) {
        lastError = 'Proxy error: $e';
        debugPrint('ScheduleParserService: Server Proxy unavailable ($e). Cascading to client AI engines...');
      }
    }

    // 1. Primary Cloud Engine: Groq LPU (Text LLM for digital PDFs, Vision LLM for images)
    if (rawJson == null &&
        (preferredEngine == 'groq' || preferredEngine == 'auto') &&
        effectiveGroqKey.isNotEmpty) {
      if (hasDigitalPdfText) {
        try {
          debugPrint('ScheduleParserService: [Tier 1 - PDF Text] Parsing COR text via Groq LPU (Llama 3.3 70B)...');
          rawJson = await _parseTextWithGroq(
            extractedText: extractedPdfText,
            apiKey: effectiveGroqKey,
          );
        } catch (e) {
          lastError = 'Groq PDF text error: $e';
          debugPrint('ScheduleParserService: Tier 1 (Groq PDF Text) failed: $e');
        }
      } else if (!isPdf) {
        try {
          debugPrint('ScheduleParserService: [Tier 1 - Vision] Attempting Groq LPU (Llama 3.2 Vision)...');
          rawJson = await _parseWithGroq(
            imageBytes: imageBytes,
            mimeType: mimeType,
            apiKey: effectiveGroqKey,
          );
        } catch (e) {
          lastError = 'Groq error: $e';
          debugPrint('ScheduleParserService: Tier 1 (Groq) failed: $e. Cascading to Tier 2 (Gemini)...');
        }
      }
    }

    // 2. Secondary Cloud Engine: Google Gemini Flash (Supports both Digital PDF Text & Native Scanned PDF DataPart)
    if (rawJson == null && effectiveGeminiKey.isNotEmpty) {
      try {
        debugPrint('ScheduleParserService: [Tier 2] Attempting Google Gemini Multimodal AI...');
        rawJson = await _parseWithGemini(
          imageBytes: imageBytes,
          mimeType: mimeType,
          apiKey: effectiveGeminiKey,
          extractedPdfText: hasDigitalPdfText ? extractedPdfText : null,
        );
      } catch (e) {
        lastError = 'Gemini error: $e';
        debugPrint('ScheduleParserService: Tier 2 (Gemini) failed: $e. Cascading to Tier 3 (OpenRouter)...');
      }
    }

    // 3. Tertiary Cloud Engine: OpenRouter Free Hub
    if (rawJson == null && effectiveOpenRouterKey.isNotEmpty) {
      if (hasDigitalPdfText) {
        try {
          debugPrint('ScheduleParserService: [Tier 3 - PDF Text] Attempting OpenRouter Text LLM...');
          rawJson = await _parseTextWithOpenRouter(
            extractedText: extractedPdfText,
            apiKey: effectiveOpenRouterKey,
          );
        } catch (e) {
          lastError = 'OpenRouter PDF text error: $e';
        }
      } else if (!isPdf) {
        try {
          debugPrint('ScheduleParserService: [Tier 3] Attempting OpenRouter Free Vision Hub...');
          rawJson = await _parseWithOpenRouter(
            imageBytes: imageBytes,
            mimeType: mimeType,
            apiKey: effectiveOpenRouterKey,
          );
        } catch (e) {
          lastError = 'OpenRouter error: $e';
          debugPrint('ScheduleParserService: Tier 3 (OpenRouter) failed: $e. Cascading to Tier 4 (Cloudflare)...');
        }
      }
    }

    // 4. Quaternary Cloud Engine: Cloudflare Workers AI Edge (Images only)
    if (rawJson == null &&
        !isPdf &&
        effectiveCfAccountId.isNotEmpty &&
        effectiveCfToken.isNotEmpty) {
      try {
        debugPrint('ScheduleParserService: [Tier 4] Attempting Cloudflare Workers AI Edge...');
        rawJson = await _parseWithCloudflare(
          imageBytes: imageBytes,
          accountId: effectiveCfAccountId,
          apiToken: effectiveCfToken,
        );
      } catch (e) {
        lastError = 'Cloudflare error: $e';
        debugPrint('ScheduleParserService: Tier 4 (Cloudflare) failed: $e. Cascading to On-Device Offline Engine...');
      }
    }

    // 5. Automatic Fallback: If cloud tiers fail or device is offline, run on-device engine
    if (rawJson == null || rawJson.trim().isEmpty) {
      debugPrint('ScheduleParserService: Cloud tiers unavailable ($lastError). Cascading to Tier 0 (On-Device Offline Engine)...');
      try {
        final offlineEntries = await OfflineScheduleParser.parseFromBytes(
          imageBytes,
          mimeType: mimeType,
        );
        if (offlineEntries.isNotEmpty) {
          debugPrint('ScheduleParserService: Successfully extracted ${offlineEntries.length} schedules via On-Device Offline Engine!');
          return offlineEntries;
        }
      } catch (offlineErr) {
        throw Exception('Offline on-device scanning and Cloud AI both failed. Cloud: $lastError | Offline: $offlineErr');
      }
      throw Exception('Multi-AI extraction could not process this document. Details: $lastError');
    }

    try {
      return _decodeScheduleJson(rawJson);
    } catch (decodeErr) {
      debugPrint('ScheduleParserService: JSON decode failed: $decodeErr. Falling back to On-Device Offline Engine...');
      try {
        final offlineEntries = await OfflineScheduleParser.parseFromBytes(
          imageBytes,
          mimeType: mimeType,
        );
        if (offlineEntries.isNotEmpty) {
          debugPrint('ScheduleParserService: Successfully extracted ${offlineEntries.length} schedules via On-Device Offline Engine after decode error!');
          return offlineEntries;
        }
      } catch (offlineErr) {
        throw Exception('Cloud AI returned malformed response and offline parser failed. Decode error: $decodeErr | Offline error: $offlineErr');
      }
      throw Exception('Failed to parse schedule JSON: $decodeErr');
    }
  }

  /// Extracts schedule using Groq LPU Vision (Llama-3.2-11b-vision-preview / 90b)
  Future<String> _parseWithGroq({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final normalizedMime = mimeType.contains('png') ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$normalizedMime;base64,$base64Image';

    final models = [
      'llama-3.2-11b-vision-preview',
      'llama-3.2-90b-vision-preview',
    ];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': _defaultPrompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': dataUri},
                  },
                ],
              }
            ],
            'temperature': 0.1,
            'max_tokens': 4096,
          }),
        ).timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final choices = body['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString();
            if (content != null && content.trim().isNotEmpty) {
              debugPrint('ScheduleParserService: Successfully extracted via Groq ($model)');
              return content;
            }
          }
        }
      } catch (e) {
        debugPrint('ScheduleParserService: Groq $model error: $e');
      }
    }

    throw Exception('Groq Vision models returned no valid schedule output.');
  }

  /// Extracts schedule using OpenRouter Free Vision Hub
  Future<String> _parseWithOpenRouter({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final normalizedMime = mimeType.contains('png') ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$normalizedMime;base64,$base64Image';

    final freeVisionModels = [
      'meta-llama/llama-3.2-11b-vision-instruct:free',
      'meta-llama/llama-3.2-90b-vision-instruct:free',
      'qwen/qwen-2-vl-72b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
    ];

    for (final model in freeVisionModels) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://github.com/Dranyl-23/Schedly',
            'X-Title': 'Reminda AI Schedule Scanner',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': _defaultPrompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': dataUri},
                  },
                ],
              }
            ],
            'temperature': 0.1,
            'max_tokens': 4096,
          }),
        ).timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final choices = body['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString();
            if (content != null && content.trim().isNotEmpty) {
              debugPrint('ScheduleParserService: Successfully extracted via OpenRouter ($model)');
              return content;
            }
          }
        }
      } catch (e) {
        debugPrint('ScheduleParserService: OpenRouter $model error: $e');
      }
    }

    throw Exception('OpenRouter Free Vision models returned no valid schedule output.');
  }

  /// Extracts schedule using Cloudflare Workers AI Edge
  Future<String> _parseWithCloudflare({
    required Uint8List imageBytes,
    required String accountId,
    required String apiToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/@cf/meta/llama-3.2-11b-vision-instruct'),
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': _defaultPrompt,
          'image': imageBytes.toList(),
          'max_tokens': 4096,
        }),
      ).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final result = body['result'];
        if (result != null && result['response'] != null) {
          final content = result['response'].toString();
          if (content.trim().isNotEmpty) {
            debugPrint('ScheduleParserService: Successfully extracted via Cloudflare Workers AI Edge');
            return content;
          }
        }
      }
    } catch (e) {
      debugPrint('ScheduleParserService: Cloudflare error: $e');
    }

    throw Exception('Cloudflare Workers AI returned no valid schedule output.');
  }

  /// Extracts schedule via the Next.js Admin Portal Server Proxy (/api/ai/parse)
  /// authenticated with the user's Firebase ID token.
  Future<String> _parseWithServerProxy({
    required String proxyUrl,
    required Uint8List imageBytes,
    required String mimeType,
    String? extractedText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not signed in for Server AI Proxy.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to obtain Firebase ID token.');
    }

    final Map<String, dynamic> payload = {
      'mimeType': mimeType,
      if (extractedText != null && extractedText.trim().isNotEmpty)
        'extractedText': extractedText
      else
        'base64Data': base64Encode(imageBytes),
    };

    final response = await http
        .post(
          Uri.parse(proxyUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map && body['schedules'] != null) {
        return jsonEncode(body['schedules']);
      }
      if (body is Map && body['rawJson'] is String) {
        return body['rawJson'] as String;
      }
    }

    throw Exception('Server Proxy returned HTTP ${response.statusCode}');
  }

  /// Parses extracted digital PDF/COR text using Groq LPU Text Models (Llama 3.3 70B / 3.1 8B)
  Future<String> _parseTextWithGroq({
    required String extractedText,
    required String apiKey,
  }) async {
    final models = [
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
    ];

    for (final model in models) {
      try {
        final response = await http
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {
                    'role': 'system',
                    'content': _defaultPrompt,
                  },
                  {
                    'role': 'user',
                    'content':
                        'Extract all schedule entries from this digital Certificate of Registration / Study Load PDF text:\n\n$extractedText',
                  },
                ],
                'temperature': 0.1,
                'max_tokens': 4096,
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final choices = body['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString();
            if (content != null && content.trim().isNotEmpty) {
              debugPrint('ScheduleParserService: Extracted PDF text via Groq ($model)');
              return content;
            }
          }
        }
      } catch (e) {
        debugPrint('ScheduleParserService: Groq text $model error: $e');
      }
    }

    throw Exception('Groq Text models returned no valid schedule output.');
  }

  /// Parses extracted digital PDF/COR text using OpenRouter Free Text LLMs
  Future<String> _parseTextWithOpenRouter({
    required String extractedText,
    required String apiKey,
  }) async {
    final models = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
      'qwen/qwen-2.5-72b-instruct:free',
    ];

    for (final model in models) {
      try {
        final response = await http
            .post(
              Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'HTTP-Referer': 'https://github.com/Dranyl-23/Schedly',
                'X-Title': 'Reminda AI Schedule Scanner',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': model,
                'messages': [
                  {
                    'role': 'system',
                    'content': _defaultPrompt,
                  },
                  {
                    'role': 'user',
                    'content':
                        'Extract all schedule entries from this digital Certificate of Registration / Study Load PDF text:\n\n$extractedText',
                  },
                ],
                'temperature': 0.1,
                'max_tokens': 4096,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final choices = body['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString();
            if (content != null && content.trim().isNotEmpty) {
              return content;
            }
          }
        }
      } catch (e) {
        debugPrint('ScheduleParserService: OpenRouter text $model error: $e');
      }
    }

    throw Exception('OpenRouter Text models returned no valid schedule output.');
  }

  /// Extracts schedule using Google Gemini Generative AI
  Future<String> _parseWithGemini({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
    String? extractedPdfText,
  }) async {
    final String normalizedMime;
    if (mimeType.contains('pdf') || mimeType.endsWith('.pdf')) {
      normalizedMime = 'application/pdf';
    } else if (mimeType.contains('png')) {
      normalizedMime = 'image/png';
    } else if (mimeType.contains('webp')) {
      normalizedMime = 'image/webp';
    } else if (mimeType.contains('heic')) {
      normalizedMime = 'image/heic';
    } else {
      normalizedMime = 'image/jpeg';
    }

    final modelNames = [
      'gemini-1.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash-8b',
      'gemini-flash-latest',
      'gemini-flash-lite-latest',
    ];

    for (final modelName in modelNames) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
          ),
        );

        final content = (extractedPdfText != null && extractedPdfText.trim().isNotEmpty)
            ? [
                Content.text(
                  '$_defaultPrompt\n\nDIGITAL PDF / COR TEXT:\n$extractedPdfText',
                ),
              ]
            : [
                Content.multi([
                  TextPart(_defaultPrompt),
                  DataPart(normalizedMime, imageBytes),
                ])
              ];

        final response = await model
            .generateContent(content)
            .timeout(const Duration(seconds: 40));

        if (response.text != null && response.text!.trim().isNotEmpty) {
          debugPrint('ScheduleParserService: Successfully extracted via Gemini ($modelName)');
          return response.text!;
        }
      } catch (e) {
        debugPrint('ScheduleParserService: Gemini $modelName failed: $e');
      }
    }

    throw Exception('Gemini Vision models returned no valid schedule output.');
  }

  /// Cleans and decodes JSON array into strongly-typed ScheduleEntry list
  List<ScheduleEntry> _decodeScheduleJson(String rawText) {
    try {
      String cleanedJson = rawText.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.replaceFirst('```json', '');
      }
      if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.replaceFirst('```', '');
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      // Find first [ and last ] to isolate JSON array from any conversational text
      final firstBracket = cleanedJson.indexOf('[');
      final lastBracket = cleanedJson.lastIndexOf(']');
      if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
        cleanedJson = cleanedJson.substring(firstBracket, lastBracket + 1);
      }

      // Remove trailing commas before closing brackets which cause jsonDecode failure
      // Safely remove trailing commas before ] and } only outside of quoted strings
      cleanedJson = _removeTrailingCommas(cleanedJson);

      final dynamic decoded = jsonDecode(cleanedJson);
      if (decoded is! List) {
        throw Exception('AI output was not in the expected schedule format.');
      }

      final List<ScheduleEntry> parsedEntries = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final rawTitle = item['title']?.toString().trim() ?? '';
          final title = rawTitle.isNotEmpty ? rawTitle : 'Untitled Schedule';
          final categoryStr = item['category']?.toString();
          final category = ScheduleCategoryExtension.fromString(categoryStr);

          final List<int> days = [];
          if (item['daysOfWeek'] is List) {
            for (final d in item['daysOfWeek']) {
              if (d is num) {
                final intDay = d.toInt();
                if (intDay >= 1 && intDay <= 7 && !days.contains(intDay)) {
                  days.add(intDay);
                }
              }
            }
          }
          if (days.isEmpty) days.add(DateTime.now().weekday);
          days.sort();

          final rawStart = item['startTime']?.toString() ?? '08:00';
          final rawEnd = item['endTime']?.toString() ?? '09:30';
          final normalizedStart = _normalizeTime(rawStart, '08:00');
          final normalizedEnd = _normalizeTime(rawEnd, '09:30');

          final rawSpans = item['spansNextDay'] as bool?;
          final spansNextDay = rawSpans ??
              TimeUtils.checkSpansOvernight(normalizedStart, normalizedEnd);

          final location = item['location']?.toString().trim();
          final notes = item['notes']?.toString().trim();

          parsedEntries.add(
            ScheduleEntry(
              title: title,
              category: category,
              daysOfWeek: days,
              startTime: normalizedStart,
              endTime: normalizedEnd,
              spansNextDay: spansNextDay,
              location: (location != null && location.isNotEmpty) ? location : null,
              notes: (notes != null && notes.isNotEmpty) ? notes : null,
              reminders: [15],
              isActive: true,
            ),
          );
        }
      }

      if (parsedEntries.isEmpty) {
        throw Exception('No schedules found in the scanned image. Please check the image quality.');
      }

      return parsedEntries;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to decode schedule output: $e');
    }
  }

  /// Normalizes any AM/PM or 24h string into standard 24-hour HH:mm
  static String _normalizeTime(String raw, String fallback) {
    try {
      String clean = raw.trim().toUpperCase();
      if (clean.isEmpty) return fallback;

      // Handle 12-hour AM/PM formats e.g. "8:00 AM", "01:30 PM", "7PM", "8:30PM"
      final amPmMatch = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$').firstMatch(clean);
      if (amPmMatch != null) {
        int hour = int.parse(amPmMatch.group(1)!);
        int minute = int.parse(amPmMatch.group(2) ?? '0');
        final period = amPmMatch.group(3)!;

        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;

        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }

      // Handle standard 24h formats e.g. "8:00", "08:30", "17:00"
      final parts = clean.split(':');
      if (parts.length == 2) {
        int hour = int.parse(parts[0].replaceAll(RegExp(r'\D'), ''));
        int minute = int.parse(parts[1].replaceAll(RegExp(r'\D'), ''));
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Remove trailing commas before ] and } while preserving string contents.
  /// This avoids corrupting valid JSON strings that happen to contain ", ]" or ", }".
  static String _removeTrailingCommas(String json) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < json.length; i++) {
      final char = json[i];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\' && inString) {
        buffer.write(char);
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      if (!inString && char == ',') {
        // Look ahead past whitespace for ] or }
        int j = i + 1;
        while (j < json.length && (json[j] == ' ' || json[j] == '\n' || json[j] == '\r' || json[j] == '\t')) {
          j++;
        }
        if (j < json.length && (json[j] == ']' || json[j] == '}')) {
          // Skip the trailing comma
          continue;
        }
      }

      buffer.write(char);
    }

    return buffer.toString();
  }
}
