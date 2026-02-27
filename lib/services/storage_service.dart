import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadLogo({
    required String userId,
    required File file,
  }) async {
    print('StorageService: Starting upload for user $userId');
    try {
      final tenantId = ThemeService.instance.databaseName;
      final path = 'images/$tenantId/branding/logo.png';
      print('StorageService: Uploading to path: $path');

      if (!await file.exists()) {
        print('StorageService: File does not exist at ${file.path}');
        return null;
      }

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);

      // Monitor progress (optional but good for debug)
      uploadTask.snapshotEvents.listen((event) {
        print(
          'StorageService: Progress: ${event.bytesTransferred}/${event.totalBytes}',
        );
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('StorageService: Upload successful. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('StorageService: Error uploading logo: $e');
      return null;
    }
  }

  Future<String?> uploadQRCode({required File file}) async {
    try {
      final tenantId = ThemeService.instance.databaseName;
      final path = 'images/$tenantId/qr_code/payment_qr.png';

      if (!await file.exists()) return null;

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('StorageService: Error uploading QR code: $e');
      return null;
    }
  }

  Future<String?> getQRCodeUrl() async {
    try {
      final tenantId = ThemeService.instance.databaseName;
      final path = 'images/$tenantId/qr_code/payment_qr.png';
      return await _storage.ref().child(path).getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadWorkerImage({
    required String userName,
    required File file,
  }) async {
    try {
      final tenantId = ThemeService.instance.databaseName;
      final fileName =
          '${userName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'images/$tenantId/worker_updates/$fileName';

      if (!await file.exists()) return null;

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('StorageService: Error uploading worker image: $e');
      return null;
    }
  }
}
