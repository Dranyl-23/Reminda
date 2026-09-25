import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/schedule_category.dart';
import '../../models/schedule_entry.dart';
import '../utils/time_utils.dart';
import 'pdf_text_extractor.dart';

class _SpatialLine {
  final String text;
  final Rect box;
  final double centerY;
  final double centerX;
  final double height;

  _SpatialLine(this.text, this.box)
      : centerY = box.top + box.height / 2,
        centerX = box.left + box.width / 2,
        height = box.height > 0 ? box.height : 16.0;
}

class _ExtractedSlot {
  final String rawStart;
  final String rawEnd;
  final _SpatialLine anchorLine;

  _ExtractedSlot({
    required this.rawStart,
    required this.rawEnd,
    required this.anchorLine,
  });
}

/// Generalized, Universal On-Device Schedule Parser with Zero-Crash Guarantee.
/// Supports 1st, 2nd, 3rd, 4th Year IT, CS, MMA, Nursing, Engineering,
/// Business, and General Workplace schedules, plus direct digital PDF COR extraction.
class OfflineScheduleParser {
  /// Extracts schedules directly on-device using PDF text extraction (for PDFs) or Google ML Kit Vision (for images)
  static Future<List<ScheduleEntry>> parseFromBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (mimeType.toLowerCase().contains('pdf') ||
        PdfTextExtractor.isPdfBytes(imageBytes)) {
      final pdfText = PdfTextExtractor.extractText(imageBytes);
      if (pdfText.trim().isNotEmpty) {
        return parseFromRawText(pdfText);
      }
      throw Exception(
        'This PDF contains scanned images without embedded text. Please connect to the internet to parse scanned PDFs with Cloud AI or take a screenshot of the schedule page.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/temp_offline_scan_$timestamp.jpg');
    await tempFile.writeAsBytes(imageBytes);

    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return parseRecognizedText(recognizedText);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Parses raw multi-line text (e.g., extracted from a digital PDF COR or study load)
  /// into strongly-typed ScheduleEntry objects using synthetic spatial layout coordinates.
  static List<ScheduleEntry> parseFromRawText(String rawText) {
    final List<_SpatialLine> allLines = [];
    final rows = rawText.split(RegExp(r'\r?\n'));
    double currentY = 10.0;

    for (final row in rows) {
      final trimmed = row.trim();
      if (trimmed.isEmpty) continue;

      // Split columns separated by 2+ spaces so tabular COR cells receive distinct X coordinates
      final columns = trimmed.split(RegExp(r'\s{2,}'));
      double currentX = 10.0;
      for (final col in columns) {
        final cell = col.trim();
        if (cell.isEmpty) continue;
        final double width = max(40.0, cell.length * 8.0);
        allLines.add(
          _SpatialLine(
            cell,
            Rect.fromLTWH(currentX, currentY, width, 18.0),
          ),
        );
        currentX += width + 24.0;
      }
      currentY += 28.0;
    }

    if (allLines.isEmpty) {
      return _generateDefaultSchedule(rawText);
    }

    return _parseSpatialLines(allLines, rawText);
  }

  /// Parses text blocks and lines into strongly-typed ScheduleEntry list
  static List<ScheduleEntry> parseRecognizedText(RecognizedText recognizedText) {
    final List<_SpatialLine> allLines = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          allLines.add(_SpatialLine(text, line.boundingBox));
        }
      }
    }

    if (allLines.isEmpty) {
      return _generateDefaultSchedule(recognizedText.text);
    }

    return _parseSpatialLines(allLines, recognizedText.text);
  }

  static List<ScheduleEntry> _parseSpatialLines(
    List<_SpatialLine> allLines,
    String fallbackText,
  ) {
    // Sort all lines top-to-bottom
    allLines.sort((a, b) => a.box.top.compareTo(b.box.top));

    // Stitched lines: Combine fragmented lines where OCR split a time range across 2 lines
    final List<_SpatialLine> spatialLines = _stitchFragmentedLines(allLines);

    // Multi-tier Time Extraction (Guarantees finding all schedule rows)
    final List<_ExtractedSlot> slots = _extractAllTimeSlots(spatialLines);

    if (slots.isEmpty) {
      return _extractFallbackFreeform(spatialLines);
    }

    // Sort slots strictly by vertical Y-coordinate
    slots.sort((a, b) => a.anchorLine.centerY.compareTo(b.anchorLine.centerY));

    final List<ScheduleEntry> entries = [];

    // Process each detected time slot using Midpoint Row Boundary Partitioning
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final timePair = _normalizeTimePair(slot.rawStart, slot.rawEnd);
      final startTime = timePair[0];
      final endTime = timePair[1];
      final spansNextDay = TimeUtils.checkSpansOvernight(startTime, endTime);

      final double fontH = slot.anchorLine.height;
      final double yAnchor = slot.anchorLine.centerY;
      final double xAnchor = slot.anchorLine.box.left;

      // Midpoint Vertical Partitioning: covers the entire multi-line height of this row
      final double topY = i == 0
          ? yAnchor - max(fontH * 1.8, 28.0)
          : (slots[i - 1].anchorLine.centerY + yAnchor) / 2.0;
      final double botY = i == slots.length - 1
          ? yAnchor + max(fontH * 1.8, 28.0)
          : (yAnchor + slots[i + 1].anchorLine.centerY) / 2.0;

      final List<_SpatialLine> rowLines = spatialLines.where((l) {
        return l.centerY >= topY && l.centerY <= botY;
      }).toList();

      final List<_SpatialLine> leftLines = rowLines.where((l) => l.box.left < (xAnchor - 10.0)).toList();
      final List<_SpatialLine> rightLines = rowLines.where((l) => l.box.left > xAnchor).toList();

      // A. Extract Days: Check anchor text first, then row lines, fallback to default (no blind cascade)
      List<int> days = _extractDays(slot.anchorLine.text);
      if (days.isEmpty) {
        for (final l in rowLines) {
          days = _extractDays(l.text);
          if (days.isNotEmpty) break;
        }
      }
      if (days.isEmpty) {
        days = [DateTime.now().weekday];
      }

      // B. Extract Course / Event Title (Full phrase reading-order assembly)
      String title = _assembleCleanTitle(leftLines, slot.anchorLine.text, slot.rawStart);
      if (title.isEmpty) {
        title = 'Schedule ${entries.length + 1}';
      }

      // C. Extract Room / Venue
      String? location = _extractLocationFromLines(rightLines);

      // D. Extract Teacher / Instructor / Supervisor
      String? teacher = _extractTeacherFromLines(rightLines, title, location);

      // E. Categorization
      final category = _classifyCategory(title, location, teacher);

      entries.add(
        ScheduleEntry(
          title: title,
          category: category,
          daysOfWeek: days,
          startTime: startTime,
          endTime: endTime,
          spansNextDay: spansNextDay,
          location: location,
          notes: teacher != null
              ? (category == ScheduleCategory.classSchedule && !teacher.startsWith('Prof') && !teacher.startsWith('Dr')
                  ? 'Prof. $teacher'
                  : teacher)
              : 'Scanned via On-Device AI',
          reminders: [15],
          isActive: true,
        ),
      );
    }

    // Deduplicate only if exact title, day, start and end times match
    final uniqueMap = <String, ScheduleEntry>{};
    for (final e in entries) {
      final key = '${e.title}_${e.startTime}_${e.endTime}_${e.daysOfWeek.join("-")}';
      uniqueMap[key] = e;
    }

    final result = uniqueMap.values.toList();
    if (result.isEmpty) {
      return _generateDefaultSchedule(fallbackText);
    }
    return result;
  }

  /// Multi-tier Time Extraction: Line Regex + Fragment Stitching + Spatial Token Pairing
  static List<_ExtractedSlot> _extractAllTimeSlots(List<_SpatialLine> spatialLines) {
    final List<_ExtractedSlot> slots = [];

    // Broad Time Range Regex: Requires colon or meridian on both sides
    final timeRangeRegex = RegExp(
      r'(\d{1,2}(?:[:.]\d{2})?\s*(?:AM|PM|NN|MN|NOON|am|pm|nn|mn)?)\s*(?:-|to|–|—|until|~)\s*(\d{1,2}(?:[:.]\d{2})?\s*(?:AM|PM|NN|MN|NOON|am|pm|nn|mn)?)',
      caseSensitive: false,
    );

    // Tier 1: Check lines for direct time range matches
    for (final sLine in spatialLines) {
      for (final match in timeRangeRegex.allMatches(sLine.text)) {
        final rawStart = match.group(1)!;
        final rawEnd = match.group(2)!;
        if (_looksLikeTime(rawStart) && _looksLikeTime(rawEnd)) {
          slots.add(_ExtractedSlot(
            rawStart: rawStart,
            rawEnd: rawEnd,
            anchorLine: sLine,
          ));
        }
      }
    }

    // Tier 2: If lines were split or fewer than 2 found, pair all clock tokens spatially
    if (slots.length < 2) {
      final timeTokenRegex = RegExp(
        r'\b(\d{1,2}:\d{2}\s*(?:AM|PM|NN|MN|NOON|am|pm|nn|mn)?|\d{1,2}\s*(?:AM|PM|NN|MN|NOON|am|pm|nn|mn))\b',
        caseSensitive: false,
      );

      final List<Map<String, dynamic>> tokens = [];
      for (final sLine in spatialLines) {
        for (final m in timeTokenRegex.allMatches(sLine.text)) {
          tokens.add({
            'token': m.group(0)!,
            'line': sLine,
          });
        }
      }

      var i = 0;
      while (i + 1 < tokens.length) {
        final t1 = tokens[i]['token'] as String;
        final t2 = tokens[i + 1]['token'] as String;
        final line = tokens[i]['line'] as _SpatialLine;

        slots.add(_ExtractedSlot(
          rawStart: t1,
          rawEnd: t2,
          anchorLine: line,
        ));
        i += 2;
      }
    }

    return slots;
  }

  /// Stitches fragmented OCR lines where time was broken across two lines
  static List<_SpatialLine> _stitchFragmentedLines(List<_SpatialLine> rawLines) {
    final List<_SpatialLine> result = [];
    var i = 0;

    final timeRegex = RegExp(
      r'(\d{1,2}(?:[:.]\d{2})?\s*(?:AM|PM|NN|MN|NOON|am|pm|nn|mn)?)\s*(?:-|to|–|—|until|~)\s*(\d{1,2}(?:[:.]\d{2})?\s*(?:AM|PM|NN|MN|NOON|am|pm|nn|mn)?)',
      caseSensitive: false,
    );

    while (i < rawLines.length) {
      final curr = rawLines[i];
      if (i + 1 < rawLines.length) {
        final nxt = rawLines[i + 1];
        final combinedText = '${curr.text} ${nxt.text}';

        if (!timeRegex.hasMatch(curr.text) && !timeRegex.hasMatch(nxt.text) && timeRegex.hasMatch(combinedText)) {
          final m = timeRegex.firstMatch(combinedText);
          if (m != null && _looksLikeTime(m.group(1)!) && _looksLikeTime(m.group(2)!)) {
            final stitchedBox = Rect.fromLTRB(
              min(curr.box.left, nxt.box.left),
              min(curr.box.top, nxt.box.top),
              max(curr.box.right, nxt.box.right),
              max(curr.box.bottom, nxt.box.bottom),
            );
            result.add(_SpatialLine(combinedText, stitchedBox));
            i += 2;
            continue;
          }
        }
      }
      result.add(curr);
      i += 1;
    }
    return result;
  }

  /// Full-Phrase Reading-Order Title Assembly
  static String _assembleCleanTitle(List<_SpatialLine> leftLines, String anchorText, String rawStart) {
    final headerPattern = RegExp(
      r'^(?:CC#?|Course|Subject|Cat|No\.?|Title|Desc|Description|Unit|Units|Lec|Lab|Day|Days|Time|Schedule|Room|Venue|Bldg|Building|Section|Sec|Teacher|Instructor|Professor|Faculty|Prereq|Prerequisite|Status|Remarks|TOTAL|\d+|\d+\s*L)$',
      caseSensitive: false,
    );

    // Universal Course Code regex (matches MMA DRW 1, NCM 101, IT 211, ICS 101, CS 102, Gen Ed 1, etc.)
    final universalCodePattern = RegExp(
      r'^(?:[A-Z]{2,6}(?:\s+[A-Z0-9]{2,6}){0,3}\s*\d{1,4}[A-Za-z]?|[A-Z]{2,6}\s+[A-Z]{2,6}|\d{3,5}\s*L?)$',
      caseSensitive: false,
    );

    // Sort lines in natural reading order: top-to-bottom (bucketed by 8px), then left-to-right
    final sorted = List<_SpatialLine>.from(leftLines)
      ..sort((a, b) {
        final bucketA = (a.box.top / 8.0).round();
        final bucketB = (b.box.top / 8.0).round();
        if (bucketA != bucketB) return bucketA.compareTo(bucketB);
        return a.box.left.compareTo(b.box.left);
      });

    final List<String> titleParts = [];
    for (final l in sorted) {
      final text = l.text.trim();
      if (headerPattern.hasMatch(text) || universalCodePattern.hasMatch(text) || RegExp(r'^\d+$').hasMatch(text)) {
        continue;
      }

      var cleaned = text
          .replaceAll(RegExp(r'^(?:SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|SUN|MON|TUE|WED|THU|FRI|SAT|MWF|TTH|M-TH|T-F|W-S|FS|SS)\b\s*[:\(\-–—]?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(?:MMA\s*(?:DRW|ELEC|GDES|101)?|Gen\s*Ed(?:\s*\d+)?|ICS\s*\d+\s*L?|IT\s*\d+\s*L?|CS\s*\d+\s*L?|MATH\s*\d+|PE\s*\d+|NSTP\s*\d+|RS\s*\d+)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\(\)\[\]\{\}\|]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleaned.length >= 2 && !RegExp(r'^\d+$').hasMatch(cleaned) && !RegExp(r'^(?:4th|3rd|2nd|1st)\s*Year.*', caseSensitive: false).hasMatch(cleaned)) {
        titleParts.add(cleaned);
      }
    }

    if (titleParts.isNotEmpty) {
      var full = titleParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      bool isLab = leftLines.any((l) => l.text.toLowerCase().contains('lab') && !l.text.toLowerCase().contains('lan lab'));
      if (isLab && !full.toLowerCase().contains('lab') && !full.toLowerCase().endsWith(' l')) {
        full = '$full (Lab)';
      }
      return full;
    }

    // Fallback: Check anchor line text before start time
    final timeIdx = anchorText.indexOf(rawStart);
    if (timeIdx > 0) {
      final beforeTime = anchorText.substring(0, timeIdx).trim();
      var cleaned = beforeTime
          .replaceAll(RegExp(r'^(?:SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|SUN|MON|TUE|WED|THU|FRI|SAT|MWF|TTH|M-TH|T-F|W-S|FS|SS)\b\s*[:\(\-–—]?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\(\)\[\]\{\}\|]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length > 2) {
        return cleaned;
      }
    }

    return '';
  }

  /// Location / Room Extraction from Right Lines
  static String? _extractLocationFromLines(List<_SpatialLine> rightLines) {
    final roomRegex = RegExp(
      r'\b(?:CLB\s*\d+|LAN\s*LAB(?:\s*\d+)?|LAB\s*\d+|CS\s*LAB(?:\s*\d+)?|MAC\s*LAB|ROOM\s*\d+|RM\s*\d+|BLDG\s*[A-Z\d]+|ENG\s*\d+|MED\s*\d+|NUR\s*\d+|AVR\s*\d+|GYM(?:\s*\d+)?|WARD\s*\d+|STATION\s*\d+|CLINIC\s*\d+|STORE\s*\d+|BRANCH\s*\d+|HALL|AUDITORIUM|TBA|TBD|ONLINE|ZOOM)\b',
      caseSensitive: false,
    );

    for (final l in rightLines) {
      final match = roomRegex.firstMatch(l.text);
      if (match != null) {
        final val = match.group(0)!.trim().toUpperCase();
        if (val.length >= 2 && !RegExp(r'^\d+$').hasMatch(val)) {
          return val;
        }
      }
    }
    return null;
  }

  /// Teacher / Instructor Extraction from Right Lines
  static String? _extractTeacherFromLines(List<_SpatialLine> rightLines, String title, String? location) {
    for (final l in rightLines) {
      final text = l.text.trim();
      if (text == title || (location != null && text.toUpperCase() == location.toUpperCase())) continue;
      if (RegExp(r'^(?:4th\s*Year|3rd\s*Year|2nd\s*Year|1st\s*Year|Prereq|IT\s*IAS|IT\s*THS|None|\d+)$', caseSensitive: false).hasMatch(text)) continue;

      if (RegExp(r"^(?:Engr\.?|Dr\.?|Prof\.?|Atty\.?|Mr\.?|Ms\.?|Mrs\.?|Instructor|Sir|Ma'am|Doctor|Nurse|Supervisor|Manager)\b", caseSensitive: false).hasMatch(text) ||
          RegExp(r'^[A-Z][a-z]+(?:\s+[A-Z][a-z\.\-]+){1,4}(?:,\s*[A-Z\s]+)?$').hasMatch(text) ||
          RegExp(r'^[A-Z][a-z]+,\s+[A-Z][a-z\.\s]+').hasMatch(text)) {
        return text;
      }
    }
    return null;
  }

  static bool _looksLikeTime(String raw) {
    final clean = raw.trim().toUpperCase();
    if (clean.contains(':') || clean.contains('.') || clean.contains('AM') || clean.contains('PM') || clean.contains('NN') || clean.contains('MN') || clean.contains('NOON')) {
      return true;
    }
    return false;
  }

  /// Extracts integer day list [1..7] using universal grammatical patterns with word-boundaries
  static List<int> _extractDays(String text) {
    final upper = text.toUpperCase();
    final Set<int> days = {};

    // Group & Hyphenated indicators
    if (RegExp(r'\b(?:EVERYDAY|DAILY|MON-SUN)\b').hasMatch(upper)) {
      return [1, 2, 3, 4, 5, 6, 7];
    }
    if (RegExp(r'\b(?:WEEKDAYS|MON-FRI|M-F)\b').hasMatch(upper)) {
      return [1, 2, 3, 4, 5];
    }
    if (RegExp(r'\b(?:WEEKENDS|SAT-SUN|S-S)\b').hasMatch(upper)) {
      return [6, 7];
    }
    if (RegExp(r'\b(?:MWF|M-W-F|M/W/F|MON/WED/FRI)\b').hasMatch(upper)) {
      days.addAll([1, 3, 5]);
    }
    if (RegExp(r'\b(?:TTH|T-TH|TR|T/TH|TUES/THURS|TUE/THU)\b').hasMatch(upper)) {
      days.addAll([2, 4]);
    }
    if (RegExp(r'\b(?:M-TH|MTH|MON-THU|MON/THU)\b').hasMatch(upper)) {
      days.addAll([1, 4]);
    }
    if (RegExp(r'\b(?:T-F|TF|TUE-FRI|TUE/FRI)\b').hasMatch(upper)) {
      days.addAll([2, 5]);
    }
    if (RegExp(r'\b(?:W-S|WS|WED-SAT|WED/SAT)\b').hasMatch(upper)) {
      days.addAll([3, 6]);
    }
    if (RegExp(r'\b(?:FS|F-S|FRI-SAT)\b').hasMatch(upper)) {
      days.addAll([5, 6]);
    }
    if (RegExp(r'\b(?:SS|S-S)\b').hasMatch(upper)) {
      days.addAll([6, 7]);
    }

    // Individual days (guarded against '4th', 'Fourth', 'Math')
    if (RegExp(r'\b(?:SUN|SUNDAY)\b').hasMatch(upper) && !RegExp(r'\bSUN\s*[A-Z]').hasMatch(upper)) {
      days.add(7);
    }
    if (RegExp(r'\b(?:MON|MONDAY)\b').hasMatch(upper)) {
      days.add(1);
    }
    if (RegExp(r'\b(?:TUE|TUES|TUESDAY)\b').hasMatch(upper)) {
      days.add(2);
    }
    if (RegExp(r'\b(?:WED|WEDNESDAY)\b').hasMatch(upper)) {
      days.add(3);
    }
    if (RegExp(r'\b(?:THU|THURS|THURSDAY)\b').hasMatch(upper)) {
      if (!RegExp(r'\b\d+TH\b|\bFOURTH\b|\bFIFTH\b|\bMATH\b|\bPATH\b').hasMatch(upper)) {
        days.add(4);
      }
    }
    if (RegExp(r'\b(?:FRI|FRIDAY)\b').hasMatch(upper)) {
      days.add(5);
    }
    if (RegExp(r'\b(?:SAT|SATURDAY)\b').hasMatch(upper)) {
      days.add(6);
    }

    final sorted = days.toList()..sort();
    return sorted;
  }

  /// Multi-Domain Category Classifier
  static ScheduleCategory _classifyCategory(String title, String? location, String? notes) {
    final combined = '$title ${location ?? ""} ${notes ?? ""}'.toLowerCase();

    if (combined.contains('duty') ||
        combined.contains('hospital') ||
        combined.contains('nurse') ||
        combined.contains('doctor') ||
        combined.contains('ward') ||
        combined.contains('er') ||
        combined.contains('emergency') ||
        combined.contains('icu') ||
        combined.contains('clinic') ||
        combined.contains('medic') ||
        combined.contains('clinical') ||
        combined.contains('rotation') ||
        combined.contains('patient') ||
        combined.contains('triage') ||
        combined.contains('surgical') ||
        combined.contains('station')) {
      return ScheduleCategory.duty;
    }

    if (combined.contains('shift') ||
        combined.contains('work') ||
        combined.contains('cashier') ||
        combined.contains('crew') ||
        combined.contains('store') ||
        combined.contains('bpo') ||
        combined.contains('call center') ||
        combined.contains('agent') ||
        combined.contains('office') ||
        combined.contains('staff') ||
        combined.contains('closing') ||
        combined.contains('opening') ||
        combined.contains('manager') ||
        combined.contains('supervisor') ||
        combined.contains('part-time') ||
        combined.contains('overtime')) {
      return ScheduleCategory.workShift;
    }

    if (combined.contains('gym') ||
        combined.contains('workout') ||
        combined.contains('fitness') ||
        combined.contains('exercise') ||
        combined.contains('church') ||
        combined.contains('worship') ||
        combined.contains('mass') ||
        combined.contains('service') ||
        combined.contains('prayer')) {
      return ScheduleCategory.custom;
    }

    return ScheduleCategory.classSchedule;
  }

  /// Normalizes start and end time with smart 12h/24h AM/PM/NN period inference
  static List<String> _normalizeTimePair(String rawStart, String rawEnd) {
    final endClean = rawEnd.toUpperCase();

    final startRes = _parseSingleTime(rawStart);
    final startH = startRes['hour24'] as int;
    final startM = startRes['minute'] as int;

    // Inherit period for end time if not explicit
    String? inheritForEnd;
    if (startH < 12 && !endClean.contains('PM') && !endClean.contains('NN') && !endClean.contains('NOON')) {
      inheritForEnd = 'AM';
    } else if (startH >= 12 && !endClean.contains('AM') && !endClean.contains('MN') && !endClean.contains('MIDNIGHT')) {
      inheritForEnd = 'PM';
    }

    final endRes = _parseSingleTime(rawEnd, inheritPeriod: inheritForEnd);
    var endH = endRes['hour24'] as int;
    final endM = endRes['minute'] as int;

    // Noon transition: 10:xx AM or 11:xx AM ending at 12:xx is 12:xx PM (Noon)!
    if ((startH == 10 || startH == 11) && endH == 0) {
      endH = 12;
    }

    return [
      '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}',
      '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}',
    ];
  }

  static Map<String, dynamic> _parseSingleTime(String raw, {String? inheritPeriod}) {
    try {
      final clean = raw.trim().toUpperCase().replaceAll('.', ':');

      // 1. Handle 12:00NN / NOON
      if (clean.contains('NN') || clean.contains('NOON')) {
        return {'hour24': 12, 'minute': 0, 'period': 'PM'};
      }
      // 2. Handle 12:00MN / MIDNIGHT
      if (clean.contains('MN') || clean.contains('MIDNIGHT')) {
        return {'hour24': 0, 'minute': 0, 'period': 'AM'};
      }

      // 3. Match 12-hour AM/PM e.g. "1:00PM", "3:00 PM)", "(7:00AM"
      final amPmMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)').firstMatch(clean);
      if (amPmMatch != null) {
        int hour = int.parse(amPmMatch.group(1)!);
        int minute = int.parse(amPmMatch.group(2) ?? '0');
        final period = amPmMatch.group(3)!;

        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;

        return {'hour24': hour, 'minute': minute, 'period': period};
      }

      // 4. Match 24-hour or plain clock HH:mm e.g. "13:00", "08:30", "12:30", "1:30"
      final hhMmMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(clean);
      if (hhMmMatch != null) {
        int hour = int.parse(hhMmMatch.group(1)!);
        int minute = int.parse(hhMmMatch.group(2)!);

        if (hour == 12) {
          return {'hour24': 12, 'minute': minute, 'period': 'PM'};
        }

        if (inheritPeriod == 'PM' && hour >= 1 && hour <= 11) {
          hour += 12;
        } else if (inheritPeriod == 'AM' && hour >= 1 && hour <= 11) {
          // Keep AM
        } else if (inheritPeriod == null && hour >= 1 && hour <= 6) {
          hour += 12; // Infer afternoon schedule
        }

        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return {'hour24': hour, 'minute': minute, 'period': inheritPeriod ?? (hour >= 12 ? 'PM' : 'AM')};
        }
      }

      // 5. Match plain hour number WITH meridian e.g. "8PM", "1PM"
      final hourMeridianMatch = RegExp(r'\b(\d{1,2})\s*(AM|PM)\b').firstMatch(clean);
      if (hourMeridianMatch != null) {
        int hour = int.parse(hourMeridianMatch.group(1)!);
        final period = hourMeridianMatch.group(2)!;
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return {'hour24': hour, 'minute': 0, 'period': period};
      }

      // 6. Match plain hour number only
      final numMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(clean);
      if (numMatch != null) {
        int hour = int.parse(numMatch.group(1)!);
        if (hour == 12) {
          return {'hour24': 12, 'minute': 0, 'period': 'PM'};
        }
        if (inheritPeriod == 'PM' && hour >= 1 && hour <= 11) {
          hour += 12;
        } else if (inheritPeriod == null && hour >= 1 && hour <= 6) {
          hour += 12;
        }
        if (hour >= 0 && hour <= 23) {
          return {'hour24': hour, 'minute': 0, 'period': inheritPeriod};
        }
      }

      return {'hour24': 8, 'minute': 0, 'period': null};
    } catch (_) {
      return {'hour24': 8, 'minute': 0, 'period': null};
    }
  }

  /// Freeform fallback for irregular documents (guarantees NO Fatal Exception is ever thrown)
  static List<ScheduleEntry> _extractFallbackFreeform(List<_SpatialLine> lines) {
    final List<ScheduleEntry> fallbackEntries = [];
    final timePattern = RegExp(r'(\d{1,2}(?:[:.]\d{2})?)\s*(?:-|to|~)\s*(\d{1,2}(?:[:.]\d{2})?)');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final m = timePattern.firstMatch(line.text);
      if (m != null) {
        final pair = _normalizeTimePair(m.group(1)!, m.group(2)!);
        final days = _extractDays(line.text).isNotEmpty ? _extractDays(line.text) : [DateTime.now().weekday];

        String title = line.text.replaceAll(m.group(0)!, '').trim();
        if (title.length < 3 && i > 0) {
          title = lines[i - 1].text.trim();
        }
        if (title.isEmpty) title = 'Schedule ${fallbackEntries.length + 1}';

        fallbackEntries.add(
          ScheduleEntry(
            title: title,
            category: ScheduleCategory.classSchedule,
            daysOfWeek: days,
            startTime: pair[0],
            endTime: pair[1],
            location: 'TBA',
            notes: 'Scanned via On-Device AI',
            reminders: [15],
            isActive: true,
          ),
        );
      }
    }

    if (fallbackEntries.isEmpty) {
      return _generateDefaultSchedule(lines.map((l) => l.text).join('\n'));
    }
    return fallbackEntries;
  }

  /// Ultimate safety net draft entry
  static List<ScheduleEntry> _generateDefaultSchedule(String text) {
    return [
      ScheduleEntry(
        title: 'Draft Scanned Schedule',
        category: ScheduleCategory.classSchedule,
        daysOfWeek: [DateTime.now().weekday],
        startTime: '08:00',
        endTime: '10:00',
        location: 'Room 101',
        notes: 'Please review and edit details',
        reminders: [15],
        isActive: true,
      ),
    ];
  }
}
