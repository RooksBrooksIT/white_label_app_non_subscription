import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class AdminDashboardBackend {
  static bool _isTicketCompleted(Map<String, dynamic> data) {
    final adminStatus = (data['adminStatus']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final engineerStatus = (data['engineerStatus']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final status = (data['status']?.toString() ?? '').trim().toLowerCase();

    final completedStatuses = {'completed', 'success', 'done', 'finished'};

    return completedStatuses.contains(adminStatus) ||
        completedStatuses.contains(engineerStatus) ||
        completedStatuses.contains(status);
  }

  static Future<Map<String, String>> getAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'name': 'Admin', 'email': ''};

    try {
      final doc = await FirestoreService.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['name'] ?? 'Admin',
          'email': data['email'] ?? user.email ?? '',
        };
      }
    } catch (e) {
      print('Error fetching admin profile: $e');
    }
    return {'name': 'Admin', 'email': user.email ?? ''};
  }

  static Future<String> getReferralCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '';

      final code = await FirestoreService.instance.getReferralCodeForAdmin(
        user.uid,
      );

      return code ?? '';
    } catch (e) {
      print('Error fetching referral code: $e');
    }
    return ''; // Return empty if not found
  }

  static Stream<int> getEngineerUpdateCountStream() {
    return FirestoreService.instance.collection('Admin_details').snapshots().map((
      snapshot,
    ) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('Engineer Update Ticket ID: ${doc.id}');
        // Check if ticket is already completed/success
        final isCompleted = _isTicketCompleted(data);

        print('  isCompleted: $isCompleted');

        if (isCompleted) {
          print('  Ticket is completed/success, skipping');
          continue;
        }

        // A ticket is considered "updated" if it has been actively modified by an engineer.
        // We exclude initial statuses: 'Assigned', 'Not Assigned', 'Ticket Created'.
        final engineerStatus = (data['engineerStatus']?.toString() ?? '')
            .trim()
            .toLowerCase();
        final isInitialStatus =
            engineerStatus == 'assigned' ||
            engineerStatus == 'not assigned' ||
            engineerStatus == 'ticket created' ||
            engineerStatus.isEmpty;

        final hasDescription =
            (data['description']?.toString() ?? '').isNotEmpty;
        final hasLastUpdated = data['lastUpdated'] != null;
        final hasAmount = (data['amount'] as num? ?? 0) > 0;

        final shouldCount =
            !isInitialStatus || hasDescription || hasLastUpdated || hasAmount;
        if (shouldCount) {
          count++;
          print('  Ticket counted');
        } else {
          print('  Ticket not counted (initial status and no updates)');
        }
      }
      print('Final Engineer Update Count: $count');
      return count;
    });
  }

  static Stream<int> getTotalCustomersStream() {
    return FirestoreService.instance
        .collection('AMC_user')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getActiveEngineersStream() {
    return FirestoreService.instance
        .collection('EngineerLogin') // Use the core login collection
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getTotalEngineersStream() {
    return FirestoreService.instance
        .collection('EngineerLogin')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Stream<int> getPendingTicketsStream() {
    // Assuming 'status' is a field in the tickets collection
    // This will count docs across multiple ticket collections if needed,
    // or just one depending on how the app is structured.
    return FirestoreService.instance
        .collection('Admin_details')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.where((doc) {
            final data = doc.data();
            return data['status'] == 'pending' || data['status'] == 'open';
          }).length,
        );
  }

  static Stream<int> getServiceTicketCountStream() {
    return FirestoreService.instance
        .collection('Admin_details')
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final jobType =
                (data['jobType']?.toString() ??
                        data['JobType']?.toString() ??
                        '')
                    .toLowerCase()
                    .trim();
            // Check if ticket is completed/success
            final isCompleted = _isTicketCompleted(data);

            print('Service Ticket ID: ${doc.id}, jobType: $jobType');
            print('  isCompleted: $isCompleted');

            if (jobType == 'service' && !isCompleted) {
              count++;
              print('  Ticket counted');
            } else {
              print('  Ticket not counted (jobType not service or completed)');
            }
          }
          print('Final Service Ticket Count: $count');
          return count;
        });
  }

  static Stream<int> getCallLogCountStream() {
    return FirestoreService.instance
        .collection('Admin_details')
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final jobType =
                (data['jobType']?.toString() ??
                        data['JobType']?.toString() ??
                        '')
                    .toLowerCase()
                    .trim();
            // Check if ticket is completed/success
            final isCompleted = _isTicketCompleted(data);

            print('Call Log Ticket ID: ${doc.id}, jobType: $jobType');
            print('  isCompleted: $isCompleted');

            if (jobType.contains('delivery') && !isCompleted) {
              count++;
              print('  Ticket counted');
            } else {
              print('  Ticket not counted (jobType not delivery or completed)');
            }
          }
          print('Final Call Log Count: $count');
          return count;
        });
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
