import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class PdfUtils {
  static Future<pw.ThemeData> loadReportTheme() async {
    pw.Font? ttfRegular;
    pw.Font? ttfBold;
    try {
      final regData = await rootBundle.load('assets/fonts/LufgaRegular.ttf');
      final boldData = await rootBundle.load('assets/fonts/LufgaBold.ttf');
      ttfRegular = pw.Font.ttf(regData);
      ttfBold = pw.Font.ttf(boldData);
    } catch (_) {
      try {
        ttfRegular = await PdfGoogleFonts.robotoRegular();
        ttfBold = await PdfGoogleFonts.robotoBold();
      } catch (_) {}
    }

    if (ttfRegular != null) {
      return pw.ThemeData.withFont(
        base: ttfRegular,
        bold: ttfBold ?? ttfRegular,
      );
    }
    return pw.ThemeData.base();
  }

  static String cleanText(String? input) {
    if (input == null) return '';
    var s = input.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll('\uFFFD', '');
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    return s.trim();
  }
  static Future<pw.MemoryImage?> fetchNetworkImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      // Add timeout and better error handling
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      } else {
        print(
          'Error fetching network image for PDF: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      // Just log the error and return null - don't break PDF generation
      print('Error fetching network image for PDF: $e');
    }
    return null;
  }

  static Future<pw.MemoryImage?> fetchAssetImage(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      print('Error loading asset image for PDF: $e');
    }
    return null;
  }
}
