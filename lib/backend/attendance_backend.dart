import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AttendanceBackend {
  /// Fetches the list of all users from the tenant's 'users' collection.
  /// Used for the Admin Dropdown.
  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      // Using FirestoreService to automatically target the correct tenant
      final snapshot = await FirestoreService.instance
          .collection('users')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['name'] ?? 'Unknown User',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'user',
        };
      }).toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  /// Fetches the list of all engineers from 'EngineerLogin' collection.
  static Future<List<Map<String, dynamic>>> getEngineers() async {
    try {
      final snapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'username': data['Username'] ?? 'Unknown',
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error fetching engineers: $e');
      return [];
    }
  }

  /// Saves or Updates the shift attendance record.
  /// Path: attendance/{engineerId}/{year}/{month}/daily/{date}
  /// Note: Added 'daily' intermediate collection to satisfy Firestore Coll/Doc pattern.
  static Future<void> saveShiftAttendance({
    required String engineerId,
    required DateTime date,
    required String shift,
    required String status,
    required String assignedBy,
    String? comment,
  }) async {
    try {
      final year = DateFormat('yyyy').format(date);
      final month = DateFormat('MM').format(date);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Path construction:
      // attendance (col) -> engineerId (doc) -> year (col) -> month (doc) -> daily (col) -> dateStr (doc)
      final docRef = FirestoreService.instance
          .collection('attendance')
          .doc(engineerId)
          .collection(year)
          .doc(month)
          .collection('daily')
          .doc(dateStr);

      final data = {
        'date': dateStr,
        'engineerId': engineerId,
        'shift': shift,
        'status': status,
        'assignedBy': assignedBy,
        'acceptedByEngineer': false,
        'comment': comment ?? '',
        'flagged': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await docRef.set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error saving shift attendance: $e');
      rethrow;
    }
  }

  /// Streams the real-time attendance record for a specific engineer and date.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getAttendanceStream({
    required String engineerId,
    required DateTime date,
  }) {
    final year = DateFormat('yyyy').format(date);
    final month = DateFormat('MM').format(date);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    return FirestoreService.instance
        .collection('attendance')
        .doc(engineerId)
        .collection(year)
        .doc(month)
        .collection('daily')
        .doc(dateStr)
        .snapshots();
  }

  /// Gets attendance history for a specific engineer
  static Stream<List<Map<String, dynamic>>> getEngineerAttendanceHistory(
    String engineerId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    Query<Map<String, dynamic>> query = FirestoreService.instance
        .collectionGroup('daily')
        .where('engineerId', isEqualTo: engineerId);

    if (fromDate != null) {
      final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
      query = query.where('date', isGreaterThanOrEqualTo: fromStr);
    }
    if (toDate != null) {
      final toStr = DateFormat('yyyy-MM-dd').format(toDate);
      query = query.where('date', isLessThanOrEqualTo: toStr);
    }

    return query.snapshots().asyncMap((snapshot) async {
      String username = 'Unknown';
      try {
        final userDoc = await FirestoreService.instance
            .collection('EngineerLogin')
            .doc(engineerId)
            .get();
        if (userDoc.exists) {
          username = userDoc.data()?['Username'] ?? 'Unknown';
        }
      } catch (e) {
        print('Error fetching user name: $e');
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'engineerUsername': username};
      }).toList();
    });
  }

  /// Gets all attendance history
  static Stream<List<Map<String, dynamic>>> getAllAttendanceHistory() {
    return FirestoreService.instance
        .collectionGroup('daily')
        .snapshots()
        .asyncMap((snapshot) async {
          final usersMap = <String, String>{};
          try {
            final engineers = await getEngineers();
            for (var e in engineers) {
              usersMap[e['uid']] = e['username'];
            }
          } catch (e) {
            print('Error fetching engineers for mapping: $e');
          }

          return snapshot.docs.map((doc) {
            final data = doc.data();
            final engId = data['engineerId'] as String?;
            String username = 'Unknown';

            if (engId != null && usersMap.containsKey(engId)) {
              username = usersMap[engId]!;
            }

            if (engId == null || username == 'Unknown') {
              try {
                final pathSegments = doc.reference.path.split('/');
                if (pathSegments.length >= 2) {
                  final potentialId = pathSegments[1];
                  if (usersMap.containsKey(potentialId)) {
                    username = usersMap[potentialId]!;
                  }
                }
              } catch (e) {}
            }

            return {...data, 'engineerUsername': username};
          }).toList();
        });
  }

  /// Marks the engineer's attendance as Present/Accepted.
  static Future<void> markAttendancePresent({
    required String engineerId,
    required DateTime date,
  }) async {
    try {
      final year = DateFormat('yyyy').format(date);
      final month = DateFormat('MM').format(date);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      await FirestoreService.instance
          .collection('attendance')
          .doc(engineerId)
          .collection(year)
          .doc(month)
          .collection('daily')
          .doc(dateStr)
          .update({
            'status': 'Present',
            'acceptedByEngineer': true,
            'loginTime': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error marking attendance present: $e');
      rethrow;
    }
  }

  /// Marks the engineer's attendance as Absent with a reason.
  static Future<void> markAttendanceAbsent({
    required String engineerId,
    required DateTime date,
    required String reason,
  }) async {
    try {
      final year = DateFormat('yyyy').format(date);
      final month = DateFormat('MM').format(date);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      await FirestoreService.instance
          .collection('attendance')
          .doc(engineerId)
          .collection(year)
          .doc(month)
          .collection('daily')
          .doc(dateStr)
          .update({
            'status': 'Absent',
            'acceptedByEngineer': false,
            'comment': reason,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error marking attendance absent: $e');
      rethrow;
    }
  }

  /// Marks attendance for multiple engineers in a single batch.
  static Future<void> markAllAttendance({
    required List<String> engineerIds,
    required DateTime date,
    required String status,
    required String shift,
    required String assignedBy,
  }) async {
    try {
      final engineerChunks = _chunkList(engineerIds, 450);

      for (var chunk in engineerChunks) {
        final firestoreBatch = FirebaseFirestore.instance.batch();

        final year = DateFormat('yyyy').format(date);
        final month = DateFormat('MM').format(date);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        for (var engineerId in chunk) {
          final docRef = FirestoreService.instance
              .collection('attendance')
              .doc(engineerId)
              .collection(year)
              .doc(month)
              .collection('daily')
              .doc(dateStr);

          final data = {
            'date': dateStr,
            'engineerId': engineerId,
            'shift': shift,
            'status': status,
            'assignedBy': assignedBy,
            'acceptedByEngineer': false,
            'flagged': false,
            'timestamp': FieldValue.serverTimestamp(),
            if (status == 'Absent') 'comment': 'Bulk Absent',
          };
          firestoreBatch.set(docRef, data, SetOptions(merge: true));
        }
        await firestoreBatch.commit();
      }
    } catch (e) {
      print('Error marking bulk attendance: $e');
      rethrow;
    }
  }

  /// Fetches attendance for all engineers on a specific date.
  static Future<List<Map<String, dynamic>>> getDailyAttendance(
    DateTime date,
  ) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final snapshot = await FirestoreService.instance
          .collectionGroup('daily')
          .where('date', isEqualTo: dateStr)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching daily attendance: $e');
      return [];
    }
  }

  /// Saves a batch of attendance records with varying statuses.
  static Future<void> batchSaveAttendance({
    required List<Map<String, dynamic>> records,
    required DateTime date,
    required String shift,
    required String assignedBy,
  }) async {
    try {
      final chunks = _chunkList(records, 450);
      final year = DateFormat('yyyy').format(date);
      final month = DateFormat('MM').format(date);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      for (var chunk in chunks) {
        final batch = FirebaseFirestore.instance.batch();

        for (var record in chunk) {
          final engineerId = record['engineerId'];
          final status = record['status'];

          final docRef = FirestoreService.instance
              .collection('attendance')
              .doc(engineerId)
              .collection(year)
              .doc(month)
              .collection('daily')
              .doc(dateStr);

          final data = {
            'date': dateStr,
            'engineerId': engineerId,
            'shift': shift,
            'status': status,
            'assignedBy': assignedBy,
            'acceptedByEngineer': false,
            'flagged': false,
            'timestamp': FieldValue.serverTimestamp(),
            if (status == 'Absent')
              'comment': record['comment'] ?? 'Marked Absent by Admin',
            if (status == 'OT') 'comment': record['comment'] ?? 'Overtime',
            if (status == 'HalfDay') 'comment': record['comment'] ?? 'Half Day',
          };

          batch.set(docRef, data, SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error batch saving attendance: $e');
      rethrow;
    }
  }

  static List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }
}
