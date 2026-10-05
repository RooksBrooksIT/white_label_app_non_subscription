import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static File? _memoryCachedQRFile;
  static String? _memoryCachedTenant;

  static File? get memoryCachedQRFile => _memoryCachedQRFile;

  static File? _memoryCachedLogoFile;
  static String? _memoryCachedLogoTenant;
  static String? _memoryCachedLogoUrl;

  static File? get memoryCachedLogoFile => _memoryCachedLogoFile;
  static String? get memoryCachedLogoUrl => _memoryCachedLogoUrl;

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

      // Immediately cache the newly uploaded logo locally for instant subsequent loads
      try {
        await cacheLogoFile(
          file: file,
          tenantId: tenantId,
          logoUrl: downloadUrl,
        );
      } catch (e) {
        print('StorageService: Error caching uploaded logo: $e');
      }

      return downloadUrl;
    } catch (e) {
      print('StorageService: Error uploading logo: $e');
      return null;
    }
  }

  /// Initialize and warm up the local branding logo cache
  Future<File?> initLogoCache({String? tenantId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
      if (effectiveTenant.isEmpty) {
        effectiveTenant = prefs.getString('tenantId') ??
            prefs.getString('databaseName') ??
            prefs.getString('admin_org_collection') ??
            '';
      }
      if (effectiveTenant.isEmpty) return null;

      final savedPath = prefs.getString('cached_logo_path_$effectiveTenant');
      if (savedPath != null) {
        final file = File(savedPath);
        if (await file.exists() && (await file.length()) > 0) {
          _memoryCachedLogoFile = file;
          _memoryCachedLogoTenant = effectiveTenant;
          return file;
        }
      }

      final docDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${docDir.path}/logo_cache/branding_logo_$effectiveTenant.png');
      if (await cacheFile.exists() && (await cacheFile.length()) > 0) {
        _memoryCachedLogoFile = cacheFile;
        _memoryCachedLogoTenant = effectiveTenant;
        await prefs.setString('cached_logo_path_$effectiveTenant', cacheFile.path);
        return cacheFile;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the in-memory cached logo file synchronously if available
  File? getSyncCachedLogoFile({String? tenantId}) {
    if (_memoryCachedLogoFile != null &&
        _memoryCachedLogoFile!.existsSync() &&
        _memoryCachedLogoFile!.lengthSync() > 0) {
      if (tenantId == null || _memoryCachedLogoTenant == tenantId) {
        return _memoryCachedLogoFile;
      }
    }
    return null;
  }

  /// Saves a logo file to local disk cache and registers in-memory cache
  Future<File?> cacheLogoFile({
    required File file,
    required String tenantId,
    String? logoUrl,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/logo_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final cacheFile = File('${cacheDir.path}/branding_logo_$tenantId.png');
      await cacheFile.writeAsBytes(await file.readAsBytes(), flush: true);

      _memoryCachedLogoFile = cacheFile;
      _memoryCachedLogoTenant = tenantId;
      _memoryCachedLogoUrl = logoUrl;

      final prefs = await SharedPreferences.getInstance();
      if (logoUrl != null && logoUrl.isNotEmpty) {
        await prefs.setString('cached_logo_url_$tenantId', logoUrl);
      }
      await prefs.setString('cached_logo_path_$tenantId', cacheFile.path);

      return cacheFile;
    } catch (e) {
      print('StorageService: Error caching logo file: $e');
      return null;
    }
  }

  /// Retrieves the branding logo file from local cache immediately if present.
  /// If not present or if URL has changed, fetches from Firebase Storage, caches it, and returns it.
  Future<File?> getCachedLogoFile({
    String? tenantId,
    String? logoUrl,
    bool forceRefresh = false,
  }) async {
    try {
      String effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
      if (effectiveTenant.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        effectiveTenant = prefs.getString('tenantId') ??
            prefs.getString('databaseName') ??
            prefs.getString('admin_org_collection') ??
            '';
      }
      if (effectiveTenant.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      final String? effectiveLogoUrl = logoUrl ?? ThemeService.instance.logoUrl ?? prefs.getString('logoUrl');
      final String? cachedUrl = prefs.getString('cached_logo_url_$effectiveTenant');

      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/logo_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final cacheFile = File('${cacheDir.path}/branding_logo_$effectiveTenant.png');

      // Check if URL has changed (Admin updated logo from another device or web)
      bool urlChanged = false;
      if (effectiveLogoUrl != null &&
          effectiveLogoUrl.isNotEmpty &&
          cachedUrl != null &&
          cachedUrl.isNotEmpty) {
        if (effectiveLogoUrl != cachedUrl) {
          urlChanged = true;
        }
      }

      // 1. Check fast in-memory cache first
      if (!forceRefresh &&
          !urlChanged &&
          _memoryCachedLogoFile != null &&
          _memoryCachedLogoTenant == effectiveTenant &&
          _memoryCachedLogoFile!.existsSync() &&
          _memoryCachedLogoFile!.lengthSync() > 0) {
        return _memoryCachedLogoFile;
      }

      // 2. Check local disk cache
      if (!forceRefresh &&
          !urlChanged &&
          await cacheFile.exists() &&
          (await cacheFile.length()) > 0) {
        _memoryCachedLogoFile = cacheFile;
        _memoryCachedLogoTenant = effectiveTenant;
        if (effectiveLogoUrl != null) {
          _memoryCachedLogoUrl = effectiveLogoUrl;
        }
        return cacheFile;
      }

      // 3. Fetch from Firebase Storage directly
      final folderRef = _storage.ref().child('images/$effectiveTenant/branding');
      Uint8List? imageBytes;

      try {
        imageBytes = await folderRef.child('logo.png').getData(10 * 1024 * 1024);
      } catch (_) {
        try {
          final listResult = await folderRef.listAll();
          if (listResult.items.isNotEmpty) {
            imageBytes = await listResult.items.first.getData(10 * 1024 * 1024);
          }
        } catch (_) {}
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        await cacheFile.writeAsBytes(imageBytes, flush: true);
        _memoryCachedLogoFile = cacheFile;
        _memoryCachedLogoTenant = effectiveTenant;
        if (effectiveLogoUrl != null) {
          _memoryCachedLogoUrl = effectiveLogoUrl;
          await prefs.setString('cached_logo_url_$effectiveTenant', effectiveLogoUrl);
        }
        await prefs.setString('cached_logo_path_$effectiveTenant', cacheFile.path);
        return cacheFile;
      }

      // Fallback: URL fetch via HTTP
      if (effectiveLogoUrl != null && effectiveLogoUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(effectiveLogoUrl));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
            _memoryCachedLogoFile = cacheFile;
            _memoryCachedLogoTenant = effectiveTenant;
            _memoryCachedLogoUrl = effectiveLogoUrl;
            await prefs.setString('cached_logo_url_$effectiveTenant', effectiveLogoUrl);
            await prefs.setString('cached_logo_path_$effectiveTenant', cacheFile.path);
            return cacheFile;
          }
        } catch (_) {}
      }

      // 4. Return existing cache file if available even if network failed
      if (await cacheFile.exists() && (await cacheFile.length()) > 0) {
        _memoryCachedLogoFile = cacheFile;
        _memoryCachedLogoTenant = effectiveTenant;
        return cacheFile;
      }

      return null;
    } catch (e) {
      print('StorageService: Error getting cached logo file: $e');
      return null;
    }
  }

  /// Invalidates the local logo cache for a tenant
  Future<void> invalidateLogoCache({String? tenantId}) async {
    try {
      String effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
      if (effectiveTenant.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        effectiveTenant = prefs.getString('tenantId') ??
            prefs.getString('databaseName') ??
            prefs.getString('admin_org_collection') ??
            '';
      }
      _memoryCachedLogoFile = null;
      _memoryCachedLogoTenant = null;
      _memoryCachedLogoUrl = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_logo_url_$effectiveTenant');
      await prefs.remove('cached_logo_path_$effectiveTenant');

      final docDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${docDir.path}/logo_cache/branding_logo_$effectiveTenant.png');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (_) {}
  }

  Future<String?> uploadQRCode({required File file}) async {
    try {
      String tenantId = ThemeService.instance.databaseName;
      if (tenantId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        tenantId = prefs.getString('tenantId') ??
            prefs.getString('databaseName') ??
            prefs.getString('admin_org_collection') ??
            '';
      }
      if (tenantId.isEmpty) {
        tenantId = 'RooksandBrooksTechnologies_20261005';
      }

      final path = 'images/$tenantId/qr_code/payment_qr.png';

      if (!await file.exists()) return null;

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Immediately cache the newly uploaded image locally for instant access
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${docDir.path}/qr_cache');
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }
        final cacheFile =
            File('${cacheDir.path}/office_pay_qr_$tenantId.png');
        await cacheFile.writeAsBytes(await file.readAsBytes(), flush: true);
        _memoryCachedQRFile = cacheFile;
        _memoryCachedTenant = tenantId;
      } catch (_) {}

      return downloadUrl;
    } catch (e) {
      print('StorageService: Error uploading QR code: $e');
      return null;
    }
  }

  Future<String?> getQRCodeUrl({String? tenantId}) async {
    try {
      String effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
      if (effectiveTenant.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        effectiveTenant = prefs.getString('tenantId') ??
            prefs.getString('databaseName') ??
            prefs.getString('admin_org_collection') ??
            '';
      }
      if (effectiveTenant.isEmpty) {
        effectiveTenant = 'RooksandBrooksTechnologies_20261005';
      }

      final path = 'images/$effectiveTenant/qr_code/payment_qr.png';
      try {
        final url = await _storage.ref().child(path).getDownloadURL();
        if (url.isNotEmpty) return url;
      } catch (_) {
        // Fallback: list items in images/$effectiveTenant/qr_code/ in case filename is different
        final listResult = await _storage
            .ref()
            .child('images/$effectiveTenant/qr_code')
            .listAll();
        if (listResult.items.isNotEmpty) {
          return await listResult.items.first.getDownloadURL();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Retrieves the QR code file from local cache immediately if present.
  /// If not present, downloads from Firebase Storage, caches it locally, and returns the file.
  /// If [forceRefresh] is true, ignores local cache, downloads fresh image, and updates cache.
  Future<File?> getCachedQRCodeFile({
    String? tenantId,
    bool forceRefresh = false,
  }) async {
    try {
      String effectiveTenant = tenantId ?? ThemeService.instance.databaseName;
      if (effectiveTenant.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        effectiveTenant = prefs.getString('tenantId') ??
            prefs.getString('databaseName') ??
            prefs.getString('admin_org_collection') ??
            '';
      }
      if (effectiveTenant.isEmpty) {
        effectiveTenant = 'RooksandBrooksTechnologies_20261005';
      }

      // Check fast in-memory cache first
      if (!forceRefresh &&
          _memoryCachedQRFile != null &&
          _memoryCachedTenant == effectiveTenant &&
          _memoryCachedQRFile!.existsSync() &&
          _memoryCachedQRFile!.lengthSync() > 0) {
        return _memoryCachedQRFile;
      }

      final docDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${docDir.path}/qr_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final cacheFile =
          File('${cacheDir.path}/office_pay_qr_$effectiveTenant.png');

      // 1. If not forcing refresh, check if local disk cache file already exists
      if (!forceRefresh &&
          await cacheFile.exists() &&
          (await cacheFile.length()) > 0) {
        _memoryCachedQRFile = cacheFile;
        _memoryCachedTenant = effectiveTenant;
        return cacheFile;
      }

      // 2. Fetch directly from Firebase Storage (faster direct download)
      final folderRef = _storage.ref().child('images/$effectiveTenant/qr_code');
      Uint8List? imageBytes;

      try {
        imageBytes =
            await folderRef.child('payment_qr.png').getData(10 * 1024 * 1024);
      } catch (_) {
        try {
          final listResult = await folderRef.listAll();
          if (listResult.items.isNotEmpty) {
            imageBytes =
                await listResult.items.first.getData(10 * 1024 * 1024);
          }
        } catch (_) {}
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        await cacheFile.writeAsBytes(imageBytes, flush: true);
        _memoryCachedQRFile = cacheFile;
        _memoryCachedTenant = effectiveTenant;
        return cacheFile;
      }

      // Fallback: URL fetch + HTTP
      final url = await getQRCodeUrl(tenantId: effectiveTenant);
      if (url != null && url.isNotEmpty) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
          _memoryCachedQRFile = cacheFile;
          _memoryCachedTenant = effectiveTenant;
          return cacheFile;
        }
      }

      // 3. Fallback to existing cache if network fetch failed
      if (await cacheFile.exists() && (await cacheFile.length()) > 0) {
        _memoryCachedQRFile = cacheFile;
        _memoryCachedTenant = effectiveTenant;
        return cacheFile;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Preload QR code cache in the background
  void preloadQRCodeCache({String? tenantId}) {
    getCachedQRCodeFile(tenantId: tenantId, forceRefresh: false);
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

  Future<String?> uploadCustomerFile({
    required String customerId,
    required File file,
    required String originalFileName,
  }) async {
    try {
      final tenantId = ThemeService.instance.databaseName;
      // File naming: {customerId}_{originalFileName}
      final fileName = '${customerId}_$originalFileName';
      // Updated Path: images/{tenantId}/customer_files/{fileName}
      final path = 'images/$tenantId/customer_files/$fileName';

      if (!await file.exists()) return null;

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('StorageService: Error uploading customer file: $e');
      return null;
    }
  }
}
