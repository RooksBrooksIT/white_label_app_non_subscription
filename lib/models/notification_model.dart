import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool seen;
  final String? type;
  final String? bookingId;
  final String? customerName;
  final String? audience;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.seen,
    this.type,
    this.bookingId,
    this.customerName,
    this.audience,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seen: data['seen'] ?? false,
      type: data['type'],
      bookingId: data['bookingId'],
      customerName: data['customerName'],
      audience: data['audience'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': seen,
      'type': type,
      'bookingId': bookingId,
      'customerName': customerName,
      'audience': audience,
    };
  }
}
