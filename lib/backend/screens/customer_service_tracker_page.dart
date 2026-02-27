import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';

class CustomerServiceTrackerBackend {
  static Stream<QuerySnapshot> getNotificationsStream(String customerName) {
    return FirestoreService.instance
        .collection('notifications')
        .where('customerName', isEqualTo: customerName)
        .snapshots();
  }

  static Future<void> markNotificationAsSeen(String docId) async {
    await FirestoreService.instance
        .collection('notifications')
        .doc(docId)
        .update({'seen': true});
  }

  static Stream<QuerySnapshot> getTicketsStream(
    String customerName,
    String mobileNumber,
  ) {
    return FirestoreService.instance
        .collection('Admin_details')
        .where('customerStatus', isEqualTo: 'Ticket Created')
        .where('customerName', isEqualTo: customerName)
        .where('mobileNumber', isEqualTo: mobileNumber)
        .snapshots();
  }

  static Future<void> cancelTicket(String documentId, String reason) async {
    await FirestoreService.instance
        .collection('Admin_details')
        .doc(documentId)
        .update({
          'adminStatus': 'Canceled',
          'customerStatus': 'Canceled',
          'Customer_decision': 'Canceled $reason',
        });
  }

  static Future<void> submitFeedback(String documentId, String feedback) async {
    await FirestoreService.instance
        .collection('Admin_details')
        .doc(documentId)
        .update({'feedback': feedback});
  }
}
