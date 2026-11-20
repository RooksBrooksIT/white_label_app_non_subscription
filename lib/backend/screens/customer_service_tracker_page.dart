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
        .collection('Admin_ticket_entry')
        .where('customerStatus', isEqualTo: 'Ticket Created')
        .where('customerName', isEqualTo: customerName)
        .where('mobileNumber', isEqualTo: mobileNumber)
        .snapshots();
  }

  static Future<void> cancelTicket(String documentId, String reason) async {
    final cancellationPayload = {
      'status': 'Cancelled',
      'adminStatus': 'Cancelled',
      'engineerStatus': 'Cancelled',
      'customerStatus': 'Cancelled',
      'Customer_decision': 'Canceled: $reason',
      'cancellationReason': reason,
      'Reason_cancel': reason,
      'cancelledByRole': 'customer',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirestoreService.instance
        .collection('Admin_ticket_entry')
        .doc(documentId)
        .set(cancellationPayload, SetOptions(merge: true));

    try {
      await FirestoreService.instance
          .collection('Raised_tickets')
          .doc(documentId)
          .set(cancellationPayload, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> submitFeedback(String documentId, String feedback) async {
    await FirestoreService.instance
        .collection('Admin_ticket_entry')
        .doc(documentId)
        .update({'feedback': feedback});
  }
}
