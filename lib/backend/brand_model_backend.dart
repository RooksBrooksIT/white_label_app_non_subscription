import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class BrandModelBackend {
  final FirestoreService _firestore = FirestoreService.instance;
  static const String devicesbrandsCollection = 'devicesbrands';

  /// Generates a Firestore-safe collection name from a device type string.
  String generateCollectionName(String devicesbrand) {
    String cleanName = devicesbrand.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return '${cleanName}Brands';
  }

  /// Generates a document ID from a brand name and model.
  String generateDocumentId(String brandName, String model) {
    String combined = '${brandName}_$model';
    return combined
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Loads all dynamic device types from Firestore.
  Future<Map<String, String>> loaddevicesbrands() async {
    Map<String, String> alldevicesbrands = {};

    QuerySnapshot customTypesSnapshot = await _firestore
        .collection(devicesbrandsCollection)
        .get();

    for (var doc in customTypesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      alldevicesbrands[data['devicesbrand'] as String] =
          data['collectionName'] as String;
    }

    return alldevicesbrands;
  }

  /// Saves a new device type to Firestore.
  Future<void> savedevicesbrand(
    String devicesbrand,
    String collectionName,
  ) async {
    final existingSnapshot = await _firestore
        .collection(devicesbrandsCollection)
        .where('devicesbrand', isEqualTo: devicesbrand)
        .get();

    if (existingSnapshot.docs.isEmpty) {
      await _firestore.collection(devicesbrandsCollection).add({
        'devicesbrand': devicesbrand,
        'collectionName': collectionName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      throw Exception('Device type "$devicesbrand" already exists');
    }
  }

  /// Adds or updates a device record.
  Future<void> saveDeviceItem({
    required String devicesbrand,
    required String collectionName,
    required String brandName,
    required String model,
    required String specification,
    required String description,
    String? editingDocumentId,
  }) async {
    if (editingDocumentId != null) {
      // Update existing
      await _firestore
          .collection(collectionName)
          .doc(editingDocumentId)
          .update({
            'brandName': brandName,
            'model': model,
            'specification': specification,
            'description': description,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } else {
      // Add new
      // First ensure device type exists in the master collection
      final devicesbrandsnapshot = await _firestore
          .collection(devicesbrandsCollection)
          .where('devicesbrand', isEqualTo: devicesbrand)
          .get();

      if (devicesbrandsnapshot.docs.isEmpty) {
        await _firestore.collection(devicesbrandsCollection).add({
          'devicesbrand': devicesbrand,
          'collectionName': collectionName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      String documentId = generateDocumentId(brandName, model);

      final existingDoc = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .get();

      if (existingDoc.exists) {
        throw Exception(
          'A device with brand "$brandName" and model "$model" already exists',
        );
      }

      // Generate brandId (BR001, BR002, etc.)
      QuerySnapshot querySnapshot = await _firestore
          .collection(collectionName)
          .orderBy('brandId', descending: true)
          .limit(1)
          .get();

      int nextId = 1;
      if (querySnapshot.docs.isNotEmpty) {
        var lastDoc = querySnapshot.docs.first;
        final data = lastDoc.data() as Map<String, dynamic>;
        if (data.containsKey('brandId')) {
          String lastBrandId = data['brandId'] as String;
          String numericPart = lastBrandId.replaceAll('BR', '');
          try {
            nextId = int.parse(numericPart) + 1;
          } catch (_) {
            nextId = 1;
          }
        }
      }

      String brandId = 'BR${nextId.toString().padLeft(3, '0')}';

      await _firestore.collection(collectionName).doc(documentId).set({
        'brandId': brandId,
        'brandName': brandName,
        'model': model,
        'specification': specification,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Saves a device entry to the 'Devices' collection.
  /// Document ID format: "deviceName_YYYY-MM-DD" (e.g., "Laptop_2024-08-12").
  /// Fields saved: deviceName, brandName, model, specification, description, createdAt.
  Future<void> saveDeviceEntry({
    required String deviceName,
    required String brandName,
    required String model,
    required String specification,
    required String description,
    String? editingDocumentId,
  }) async {
    final cleanDeviceName = deviceName.trim();
    final cleanBrandName = brandName.trim();
    final cleanModel = model.trim();
    final cleanSpec = specification.trim();
    final cleanDesc = description.trim();

    if (editingDocumentId != null) {
      // Update existing document without overwriting fields with empty values
      final Map<String, dynamic> updateData = {
        if (cleanDeviceName.isNotEmpty) 'deviceName': cleanDeviceName,
        if (cleanBrandName.isNotEmpty) 'brandName': cleanBrandName,
        if (cleanModel.isNotEmpty) 'model': cleanModel,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (cleanSpec.isNotEmpty) {
        updateData['specification'] = cleanSpec;
      }
      if (cleanDesc.isNotEmpty) {
        updateData['description'] = cleanDesc;
      }
      await _firestore
          .collection('Devices')
          .doc(editingDocumentId)
          .update(updateData);
    } else {
      // Generate document ID: "deviceName_YYYY-MM-DD"
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final safeDeviceName = cleanDeviceName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '_',
      );
      final documentId = '${safeDeviceName}_$dateStr';

      final Map<String, dynamic> docData = {
        'deviceName': cleanDeviceName,
        'brandName': cleanBrandName,
        'model': cleanModel,
        'specification': cleanSpec,
        'description': cleanDesc,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Check for duplicates
      final existing = await _firestore
          .collection('Devices')
          .doc(documentId)
          .get();
      if (existing.exists) {
        // Append a counter suffix to make it unique
        int counter = 1;
        String uniqueId = '${documentId}_$counter';
        while (true) {
          final check = await _firestore
              .collection('Devices')
              .doc(uniqueId)
              .get();
          if (!check.exists) break;
          counter++;
          uniqueId = '${documentId}_$counter';
        }
        await _firestore.collection('Devices').doc(uniqueId).set(docData);
      } else {
        await _firestore.collection('Devices').doc(documentId).set(docData);
      }
    }
  }

  /// Deletes a device record.
  Future<void> deleteDeviceItem(
    String collectionName,
    String documentId,
  ) async {
    await _firestore.collection(collectionName).doc(documentId).delete();
  }

  /// Deletes a device type and all its associated device records.
  Future<void> deletedevicesbrand(
    String devicesbrand,
    String collectionName,
  ) async {
    // Delete all devices in the collection
    QuerySnapshot snapshot = await _firestore.collection(collectionName).get();

    for (QueryDocumentSnapshot doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the device type entry
    QuerySnapshot devicesbrandDocs = await _firestore
        .collection(devicesbrandsCollection)
        .where('devicesbrand', isEqualTo: devicesbrand)
        .get();

    for (QueryDocumentSnapshot doc in devicesbrandDocs.docs) {
      await doc.reference.delete();
    }
  }

  /// Returns a stream of devices for a given collection.
  Stream<QuerySnapshot> streamDevices(String collectionName) {
    return _firestore.collection(collectionName).snapshots();
  }

  /// Fetches paginated devices from Firestore using document snapshot cursor.
  Future<QuerySnapshot> fetchDevicesPaginated({
    String collectionName = 'Devices',
    int limit = 10,
    DocumentSnapshot? startAfter,
    String? orderByField,
    bool descending = false,
  }) async {
    Query query = _firestore.collection(collectionName);
    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.limit(limit).get();
  }

  /// Fetches all unique device types from 'Devices', 'deviceDetails', and 'devicesbrands' collections.
  /// Eliminates duplicates (case-insensitive), sorts alphabetically, and appends 'Others'.
  Future<List<String>> fetchAllDeviceTypes() async {
    try {
      final Map<String, String> normalizedMap =
          {}; // lower -> canonical display

      // 1. From 'Devices' (Admin equipment catalog)
      try {
        final snapshot = await _firestore.collection('Devices').get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final name = (data['deviceName'] ?? data['deviceType'] ?? '')
              .toString()
              .trim();
          if (name.isNotEmpty && name.toLowerCase() != 'others') {
            final lower = name.toLowerCase();
            normalizedMap.putIfAbsent(lower, () => name);
          }
        }
      } catch (e) {
        // Continue
      }

      // 2. From 'deviceDetails' (Admin Device Configuration module)
      try {
        final snapshot = await _firestore.collection('deviceDetails').get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final name = (data['deviceType'] ?? doc.id).toString().trim();
          if (name.isNotEmpty && name.toLowerCase() != 'others') {
            final lower = name.toLowerCase();
            normalizedMap.putIfAbsent(lower, () => name);
          }
        }
      } catch (e) {
        // Continue
      }

      // 3. From 'devicesbrands' (BrandModelBackend dynamic master types)
      try {
        final snapshot = await _firestore
            .collection(devicesbrandsCollection)
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final name = (data['devicesbrand'] ?? '').toString().trim();
          if (name.isNotEmpty && name.toLowerCase() != 'others') {
            final lower = name.toLowerCase();
            normalizedMap.putIfAbsent(lower, () => name);
          }
        }
      } catch (e) {
        // Continue
      }

      final list = normalizedMap.values.toList();
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      list.add('Others');
      return list;
    } catch (e) {
      return ['Others'];
    }
  }

  /// Fetches all device brands dynamically from 'Devices', 'devicebrands', and 'devicesbrands'.
  /// If [deviceType] is provided, prioritizes brands configured for that device type in 'Devices'.
  /// Eliminates duplicates (case-insensitive), sorts alphabetically, and appends 'Others'.
  Future<List<String>> fetchAllDeviceBrands([String? deviceType]) async {
    try {
      final Map<String, String> normalizedMap =
          {}; // lower -> canonical display

      // If a specific device type is provided (and not 'Others'), first try to find brands linked to that type
      if (deviceType != null &&
          deviceType.trim().isNotEmpty &&
          deviceType.trim().toLowerCase() != 'others') {
        final targetType = deviceType.trim().toLowerCase();
        try {
          final snapshot = await _firestore.collection('Devices').get();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final dName = (data['deviceName'] ?? data['deviceType'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (dName == targetType) {
              final b = (data['brandName'] ?? data['brand'] ?? '')
                  .toString()
                  .trim();
              if (b.isNotEmpty &&
                  b.toLowerCase() != 'others' &&
                  b.toLowerCase() != 'general') {
                normalizedMap.putIfAbsent(b.toLowerCase(), () => b);
              }
            }
          }
        } catch (_) {}
      }

      // If no specific brands were found for that type, or if no deviceType was specified,
      // load all configured brands from backend configuration collections
      if (normalizedMap.isEmpty) {
        // 1. From 'Devices'
        try {
          final snapshot = await _firestore.collection('Devices').get();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final b = (data['brandName'] ?? data['brand'] ?? '')
                .toString()
                .trim();
            if (b.isNotEmpty &&
                b.toLowerCase() != 'others' &&
                b.toLowerCase() != 'general') {
              normalizedMap.putIfAbsent(b.toLowerCase(), () => b);
            }
          }
        } catch (_) {}

        // 2. From 'devicebrands'
        try {
          final snapshot = await _firestore.collection('devicebrands').get();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final b =
                (data['devicebrand'] ??
                        data['brand'] ??
                        data['brandName'] ??
                        '')
                    .toString()
                    .trim();
            if (b.isNotEmpty &&
                b.toLowerCase() != 'others' &&
                b.toLowerCase() != 'general') {
              normalizedMap.putIfAbsent(b.toLowerCase(), () => b);
            }
          }
        } catch (_) {}

        // 3. From 'devicesbrands'
        try {
          final snapshot = await _firestore
              .collection(devicesbrandsCollection)
              .get();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final b =
                (data['devicesbrand'] ?? data['devicebrand'] ?? data['brand'])
                    ?.toString()
                    .trim();
            if (b != null &&
                b.isNotEmpty &&
                b.toLowerCase() != 'others' &&
                b.toLowerCase() != 'general') {
              normalizedMap.putIfAbsent(b.toLowerCase(), () => b);
            }
          }
        } catch (_) {}
      }

      final list = normalizedMap.values.toList();
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      list.add('Others');
      return list;
    } catch (e) {
      return ['Others'];
    }
  }

  /// Persists newly entered custom Device Type and/or Device Brand (from "Others")
  /// to the backend configuration collections ('Devices', 'deviceDetails', 'devicebrands').
  /// Prevents duplicates (case-insensitive check) and ensures they become available for future ticket creation.
  Future<void> saveCustomDeviceConfiguration({
    required String deviceType,
    required String deviceBrand,
  }) async {
    final cleanType = deviceType.trim();
    final cleanBrand = deviceBrand.trim();

    final isCustomType =
        cleanType.isNotEmpty && cleanType.toLowerCase() != 'others';
    final isCustomBrand =
        cleanBrand.isNotEmpty && cleanBrand.toLowerCase() != 'others';

    if (!isCustomType && !isCustomBrand) return;

    try {
      // 1. If custom device type, ensure it exists in 'deviceDetails' (Admin Device Config)
      if (isCustomType) {
        final existingTypeSnapshot = await _firestore
            .collection('deviceDetails')
            .get();
        final alreadyInDetails = existingTypeSnapshot.docs.any((doc) {
          final data = doc.data();
          final t = (data['deviceType'] ?? doc.id).toString().trim();
          return t.toLowerCase() == cleanType.toLowerCase();
        });

        if (!alreadyInDetails) {
          // Generate next device ID (DE001, DE002, etc.) matching admin_device_config_page
          int maxNumber = 0;
          for (var doc in existingTypeSnapshot.docs) {
            final data = doc.data();
            final deviceId = data['deviceId'] as String?;
            if (deviceId != null && deviceId.startsWith('DE')) {
              final numberPart = deviceId.substring(2);
              final num = int.tryParse(numberPart) ?? 0;
              if (num > maxNumber) maxNumber = num;
            }
          }
          final nextDeviceId =
              'DE${(maxNumber + 1).toString().padLeft(3, '0')}';

          await _firestore.collection('deviceDetails').doc(cleanType).set({
            'deviceType': cleanType,
            'description': 'Auto-configured from ticket creation',
            'deviceId': nextDeviceId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 2. If custom brand, ensure it exists in 'devicebrands'
      if (isCustomBrand) {
        final existingBrandSnapshot = await _firestore
            .collection('devicebrands')
            .get();
        final alreadyInBrands = existingBrandSnapshot.docs.any((doc) {
          final data = doc.data();
          final b =
              (data['devicebrand'] ?? data['brand'] ?? data['brandName'] ?? '')
                  .toString()
                  .trim();
          return b.toLowerCase() == cleanBrand.toLowerCase();
        });

        if (!alreadyInBrands) {
          await _firestore.collection('devicebrands').add({
            'devicebrand': cleanBrand,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 3. Ensure representation in 'Devices' collection (Admin Device Catalog)
      final targetType = isCustomType
          ? cleanType
          : (cleanType.isNotEmpty ? cleanType : 'General');
      final targetBrand = isCustomBrand
          ? cleanBrand
          : (cleanBrand.isNotEmpty ? cleanBrand : 'General');

      final devicesSnapshot = await _firestore.collection('Devices').get();
      final alreadyInDevices = devicesSnapshot.docs.any((doc) {
        final data = doc.data();
        final dName = (data['deviceName'] ?? data['deviceType'] ?? '')
            .toString()
            .trim();
        final bName = (data['brandName'] ?? data['brand'] ?? '')
            .toString()
            .trim();
        return dName.toLowerCase() == targetType.toLowerCase() &&
            bName.toLowerCase() == targetBrand.toLowerCase();
      });

      if (!alreadyInDevices) {
        await saveDeviceEntry(
          deviceName: targetType,
          brandName: targetBrand,
          model: 'Standard',
          specification: 'Auto-configured from ticket creation',
          description: 'Added via Others option',
        );
      }
    } catch (_) {
      // Graceful error recovery
    }
  }
}
