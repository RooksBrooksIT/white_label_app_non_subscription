import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String customerName;
  final String bookingId;
  final String deviceType;
  final String deviceBrand;
  final String deviceCondition;
  final String message;
  final String address;
  final String mobileNumber;
  final String jobType; // Add jobType field
  final String amount; // Add amount field
  final String customerid; // Add customerid field
  String deviceName;
  String problem;
  String assignedEngineer;
  final Timestamp timestamp; // Add timestamp field

  static const String unassigned = 'Unassigned';
  static const String assigned = 'Assigned';
  static const String pending = 'Pending';
  static const String waitingForVendor = 'WaitingForVendor';

  // Constructor
  Customer({
    required this.customerName,
    required this.bookingId,
    required this.deviceType,
    required this.deviceBrand,
    required this.deviceCondition,
    required this.message,
    required this.address,
    required this.mobileNumber,
    required this.jobType,
    required this.customerid,
    required this.amount, // Add amount parameter
    this.deviceName = '',
    this.problem = '',
    this.assignedEngineer = '',
    required this.timestamp,
  });

  // CopyWith method
  Customer copyWith({
    String? customerName,
    String? bookingId,
    String? deviceType,
    String? deviceBrand,
    String? deviceCondition,
    String? message,
    String? address,
    String? mobileNumber,
    String? jobType,
    String? amount,
    String? deviceName,
    String? problem,
    String? assignedEngineer,
    Timestamp? timestamp,
  }) {
    return Customer(
      customerName: customerName ?? this.customerName,
      bookingId: bookingId ?? this.bookingId,
      deviceType: deviceType ?? this.deviceType,
      deviceBrand: deviceBrand ?? this.deviceBrand,
      deviceCondition: deviceCondition ?? this.deviceCondition,
      message: message ?? this.message,
      address: address ?? this.address,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      jobType: jobType ?? this.jobType,
      amount: amount ?? this.amount,
      deviceName: deviceName ?? this.deviceName,
      problem: problem ?? this.problem,
      assignedEngineer: assignedEngineer ?? this.assignedEngineer,
      timestamp: timestamp ?? this.timestamp,
      customerid: customerid ?? customerid,
    );
  }

  // Convert Customer to Firestore map
  Map<String, dynamic> toMap() {
    return {
      "customerName": customerName,
      "bookingId": bookingId,
      "deviceType": deviceType,
      "deviceBrand": deviceBrand,
      "deviceCondition": deviceCondition,
      "message": message,
      "address": address,
      "mobileNumber": mobileNumber,
      "JobType": jobType,
      "amount": amount, // Include amount in the map
      "DeviceName": deviceName,
      "Problem": problem,
      "AssignedEngineer": assignedEngineer,
      "timestamp": timestamp,
    };
  }

  // Convert Firestore document to Customer object
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Debug: Print the data fetched from Firestore
    print("Fetched data from Firestore: $data");

    return Customer(
      customerName: data?['customerName'] ?? '',
      bookingId: data?['bookingId'] ?? '',
      deviceType: data?['deviceType'] ?? '',
      deviceBrand: data?['deviceBrand'] ?? '',
      deviceCondition: data?['deviceCondition'] ?? '',
      message: data?['message'] ?? '',
      address: data?['address'] ?? '',
      mobileNumber: data?['mobileNumber'] ?? "",
      jobType: data?['JobType'] ?? '',
      amount: data?['amount'] ?? '', // Handle amount from Firestore
      deviceName: data?['DeviceName'] ?? '',
      problem: data?['Problem'] ?? '',
      assignedEngineer: data?['AssignedEngineer'] ?? '',
      timestamp: _parseTimestamp(data?['timestamp']),
      customerid: data?['id'] ?? '',
    );
  }

  static Timestamp _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String) {
      DateTime? dt = DateTime.tryParse(v);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return Timestamp.now();
  }

  String? get id => customerid;

  Null get status => null;

  // get customerid => null;

  // Fetch list of Customers from Firestore query snapshot
  static List<Customer> fromFirestoreList(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
  }

  // To Map List for Firestore update
  static List<Map<String, dynamic>> toMapList(List<Customer> customers) {
    return customers.map((customer) => customer.toMap()).toList();
  }

  // Update problem description
  void updateProblem(String newProblem) {
    problem = newProblem;
  }

  // Update device name
  void updateDeviceName(String newDeviceName) {
    deviceName = newDeviceName;
  }

  // Update assigned engineer
  void updateAssignedEngineer(String newEngineer) {
    assignedEngineer = newEngineer;
  }

  // Convert customer details into readable string
  String formatCustomerDetails() {
    return '''
Customer Name: $customerName
Booking ID: $bookingId
Device Type: $deviceType
Device Brand: $deviceBrand
Device Condition: $deviceCondition
Message: $message
Address: $address
Device Name: $deviceName
Problem: $problem
Assigned Engineer: $assignedEngineer
Timestamp: $timestamp
    ''';
  }

  static void empty() {}

  // Update Firestore document with customer details
}
