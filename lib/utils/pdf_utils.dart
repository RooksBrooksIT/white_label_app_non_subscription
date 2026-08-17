import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

class PdfUtils {
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
