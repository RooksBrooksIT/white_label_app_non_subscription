import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class EmailService {
  static const String _mailCollection = 'mail';

  static Future<bool> sendReceiptWithAttachment({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlContent,
    required File attachment,
    required String attachmentName,
  }) async {
    try {
      debugPrint('Converting receipt to base64 for Firestore email trigger...');

      // Read file and convert to base64
      final bytes = await attachment.readAsBytes();
      final base64Attachment = base64Encode(bytes);

      // 2. Add to 'mail' collection for Firebase Trigger Email Extension
      // Standard schema for the extension:
      // https://extensions.dev/extensions/firebase/firestore-send-email
      final payload = {
        'to': recipientEmail,
        'message': {
          'subject': subject,
          'html': htmlContent,
          'attachments': [
            {
              'filename': attachmentName,
              'content': base64Attachment,
              'encoding': 'base64',
            },
          ],
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      debugPrint('Firestore Email Payload: $payload');
      debugPrint('Payload "to" field value: ${payload['to']}');

      await FirebaseFirestore.instance.collection(_mailCollection).add(payload);

      debugPrint(
        'Email trigger document added to Firestore collection: $_mailCollection',
      );
      return true;
    } catch (e) {
      debugPrint('Error triggering email via Firestore: $e');
      return false;
    }
  }
}
