import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Pure-Dart PDF Text Stream Extractor for digital University Certificates of Registration (COR),
/// study loads, and shift rosters.
///
/// Decompresses `/FlateDecode` streams via `dart:io`'s native [zlib] codec and parses
/// PDF text-showing operators (`Tj`, `TJ`, `'`, `"`) without requiring external native plugins.
class PdfTextExtractor {
  PdfTextExtractor._();

  /// Checks whether [bytes] begins with the `%PDF-` magic header.
  static bool isPdfBytes(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  /// Extracts human-readable text from a digital PDF document.
  /// Returns an empty string if the PDF only contains scanned raster images without text streams.
  static String extractText(Uint8List pdfBytes) {
    if (!isPdfBytes(pdfBytes)) return '';

    final String rawLatin = latin1.decode(pdfBytes, allowInvalid: true);
    final StringBuffer extracted = StringBuffer();

    final RegExp streamRegex = RegExp(r'stream\r?\n', multiLine: true);
    int searchIndex = 0;

    while (searchIndex < rawLatin.length) {
      final match = streamRegex.firstMatch(rawLatin.substring(searchIndex));
      if (match == null) break;

      final int streamDataStart = searchIndex + match.end;
      final int endStreamPos = rawLatin.indexOf('endstream', streamDataStart);
      if (endStreamPos == -1) break;

      // Inspect dictionary header preceding `stream` to see if it is an Image XObject
      final int dictStart =
          (searchIndex + match.start - 320).clamp(0, rawLatin.length);
      final String dictHeader =
          rawLatin.substring(dictStart, searchIndex + match.start);

      final bool isImageStream = dictHeader.contains('/Subtype /Image') ||
          dictHeader.contains('/Subtype/Image');

      if (!isImageStream && endStreamPos > streamDataStart) {
        int sliceEnd = endStreamPos;
        if (sliceEnd > streamDataStart && pdfBytes[sliceEnd - 1] == 0x0A) {
          sliceEnd--;
        }
        if (sliceEnd > streamDataStart && pdfBytes[sliceEnd - 1] == 0x0D) {
          sliceEnd--;
        }

        final Uint8List streamBytes =
            pdfBytes.sublist(streamDataStart, sliceEnd);
        String? decodedStream;

        if (dictHeader.contains('/FlateDecode')) {
          try {
            final decompressed = zlib.decode(streamBytes);
            decodedStream = latin1.decode(decompressed, allowInvalid: true);
          } catch (_) {
            // Try raw inflate without zlib header if standard zlib decode fails
            try {
              final rawZlib = ZLibDecoder(raw: true).convert(streamBytes);
              decodedStream = latin1.decode(rawZlib, allowInvalid: true);
            } catch (_) {}
          }
        } else if (!dictHeader.contains('/DCTDecode') &&
            !dictHeader.contains('/JPXDecode')) {
          decodedStream = latin1.decode(streamBytes, allowInvalid: true);
        }

        if (decodedStream != null && decodedStream.contains('BT')) {
          final String streamText = _extractTextFromContentStream(decodedStream);
          if (streamText.trim().isNotEmpty) {
            extracted.writeln(streamText.trim());
          }
        }
      }

      searchIndex = endStreamPos + 9;
    }

    return _cleanExtractedText(extracted.toString());
  }

  /// Parses `BT ... ET` text blocks from a decoded PDF content stream.
  static String _extractTextFromContentStream(String content) {
    final StringBuffer out = StringBuffer();
    int idx = 0;

    while (idx < content.length) {
      final int btPos = content.indexOf('BT', idx);
      if (btPos == -1) break;
      final int etPos = content.indexOf('ET', btPos + 2);
      final int blockEnd = etPos != -1 ? etPos : content.length;

      final String block = content.substring(btPos + 2, blockEnd);
      _parseTextBlock(block, out);
      out.write('\n');

      idx = blockEnd + 2;
    }

    return out.toString();
  }

  static void _parseTextBlock(String block, StringBuffer out) {
    final lines = block.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Move to next line operators: Td, TD, T*, ', "
      final bool isNewLineOp =
          RegExp(r'(?:^|\s)(?:T\*|Td|TD|Tm)\b').hasMatch(trimmed);
      if (isNewLineOp && out.isNotEmpty && !out.toString().endsWith('\n')) {
        // Check if vertical Y delta is non-zero on Td/TD (e.g., `0 -14 Td`)
        final tdMatch =
            RegExp(r'([-\d.]+)\s+([-\d.]+)\s+T[dD]\b').firstMatch(trimmed);
        if (tdMatch != null) {
          final dy = double.tryParse(tdMatch.group(2) ?? '0') ?? 0;
          if (dy.abs() > 1.5) {
            out.write('\n');
          } else {
            out.write('  ');
          }
        } else if (trimmed.contains('T*')) {
          out.write('\n');
        }
      }

      // Extract all literal strings (...) and TJ arrays [(...)] on this line
      int i = 0;
      bool wroteToken = false;
      while (i < trimmed.length) {
        if (trimmed[i] == '(') {
          final literal = _readPdfLiteralString(trimmed, i);
          if (literal.text.isNotEmpty) {
            out.write(literal.text);
            wroteToken = true;
          }
          i = literal.nextIndex;
        } else if (trimmed[i] == '<' &&
            (i + 1 < trimmed.length && trimmed[i + 1] != '<')) {
          final int closeHex = trimmed.indexOf('>', i + 1);
          if (closeHex != -1) {
            final String hexStr = trimmed.substring(i + 1, closeHex);
            final String decodedHex = _decodePdfHexString(hexStr);
            if (decodedHex.isNotEmpty) {
              out.write(decodedHex);
              wroteToken = true;
            }
            i = closeHex + 1;
          } else {
            i++;
          }
        } else {
          // Check for large negative kerning adjustments in TJ arrays e.g. -250 -> space
          if (trimmed[i] == '-') {
            final numMatch = RegExp(r'^-\d+').firstMatch(trimmed.substring(i));
            if (numMatch != null) {
              final kern = int.tryParse(numMatch.group(0)!) ?? 0;
              if (kern <= -120) {
                out.write(' ');
              }
              i += numMatch.group(0)!.length;
              continue;
            }
          }
          i++;
        }
      }

      if (wroteToken) {
        out.write(' ');
      }
    }
  }

  static ({String text, int nextIndex}) _readPdfLiteralString(
      String src, int startParen) {
    final StringBuffer buf = StringBuffer();
    int depth = 0;
    int i = startParen;

    while (i < src.length) {
      final String ch = src[i];
      if (ch == r'\') {
        if (i + 1 < src.length) {
          final String next = src[i + 1];
          switch (next) {
            case 'n':
              buf.write('\n');
              i += 2;
              continue;
            case 'r':
              buf.write('\r');
              i += 2;
              continue;
            case 't':
              buf.write('\t');
              i += 2;
              continue;
            case '(':
            case ')':
            case r'\':
              buf.write(next);
              i += 2;
              continue;
            default:
              // Check octal escape \ddd
              final octMatch =
                  RegExp(r'^[0-7]{1,3}').firstMatch(src.substring(i + 1));
              if (octMatch != null) {
                final octStr = octMatch.group(0)!;
                final code = int.tryParse(octStr, radix: 8);
                if (code != null && code >= 32 && code <= 126) {
                  buf.writeCharCode(code);
                }
                i += 1 + octStr.length;
                continue;
              }
              buf.write(next);
              i += 2;
              continue;
          }
        }
      } else if (ch == '(') {
        if (depth > 0) buf.write('(');
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth <= 0) {
          return (text: buf.toString(), nextIndex: i + 1);
        }
        buf.write(')');
      } else {
        buf.write(ch);
      }
      i++;
    }

    return (text: buf.toString(), nextIndex: src.length);
  }

  static String _decodePdfHexString(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (clean.isEmpty) return '';
    final StringBuffer out = StringBuffer();

    // Support both 1-byte ASCII hex and 2-byte UTF-16BE hex
    final bool isUtf16 = clean.length >= 4 &&
        (clean.startsWith('00') || clean.toUpperCase().startsWith('FEFF'));
    final int step = isUtf16 ? 4 : 2;

    for (int i = 0; i + step <= clean.length; i += step) {
      final int? code = int.tryParse(clean.substring(i, i + step), radix: 16);
      if (code != null && code >= 32 && code <= 126) {
        out.writeCharCode(code);
      } else if (code == 9 || code == 10 || code == 13) {
        out.write(' ');
      }
    }
    return out.toString();
  }

  static String _cleanExtractedText(String raw) {
    if (raw.trim().isEmpty) return '';
    final lines = raw
        .split('\n')
        .map((line) => line
            .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
            .replaceAll(RegExp(r'\s{3,}'), '  ')
            .trim())
        .where((line) => line.length >= 2)
        .toList();
    return lines.join('\n');
  }
}
