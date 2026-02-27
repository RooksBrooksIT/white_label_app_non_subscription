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

  /// Fetches all device brands from the 'devicebrands' or 'devicesbrands' collection.
  Future<List<String>> fetchAllDeviceBrands() async {
    try {
      // Try 'devicebrands' as requested by user
      var snapshot = await _firestore.collection('devicebrands').get();
      var brands = snapshot.docs
          .map((doc) => doc.data()['devicebrand']?.toString().trim())
          .where((brand) => brand != null && brand.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      if (brands.isEmpty) {
        // Fallback to 'devicesbrands' (plural s) if empty
        snapshot = await _firestore.collection('devicesbrands').get();
        brands = snapshot.docs
            .map((doc) {
              final data = doc.data();
              return (data['devicesbrand'] ??
                      data['devicebrand'] ??
                      data['brand'])
                  ?.toString()
                  .trim();
            })
            .where((brand) => brand != null && brand.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
      }

      brands.sort();
      return brands;
    } catch (e) {
      print('Error fetching device brands: $e');
      return [];
    }
  }
}
