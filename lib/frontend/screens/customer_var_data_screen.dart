import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String customerName;
  final String ticketId;
  final String deviceType;
  final String deviceBrand;
  final String deviceCondition;
  final String issueDescription;
  final String address;
  final String mobileNumber;
  final String jobType; // Add jobType field
  final String amount; // Add amount field
  final String customerid; // Add customerid field
  final String customerType; // "amc", "normal", "nonamc", etc.
  String deviceName;
  String problem;
  String assignedEngineer;
  final Timestamp timestamp; // Add timestamp field
  final String? customerFileUrl; // New field
  final String? fileName; // New field

  static const String unassigned = 'Unassigned';
  static const String assigned = 'Assigned';
  static const String pending = 'Pending';
  static const String waitingForVendor = 'WaitingForVendor';

  // Constructor
  Customer({
    required this.customerName,
    String? ticketId,
    String? bookingId,
    required this.deviceType,
    required this.deviceBrand,
    required this.deviceCondition,
    String? issueDescription,
    String? message,
    required this.address,
    required this.mobileNumber,
    required this.jobType,
    required this.customerid,
    this.customerType = '',
    required this.amount, // Add amount parameter
    this.deviceName = '',
    this.problem = '',
    this.assignedEngineer = '',
    required this.timestamp,
    this.customerFileUrl,
    this.fileName,
  })  : ticketId = ticketId ?? bookingId ?? '',
        issueDescription = issueDescription ?? message ?? '';

  // CopyWith method
  Customer copyWith({
    String? customerName,
    String? ticketId,
    String? deviceType,
    String? deviceBrand,
    String? deviceCondition,
    String? issueDescription,
    String? address,
    String? mobileNumber,
    String? jobType,
    String? amount,
    String? deviceName,
    String? problem,
    String? assignedEngineer,
    Timestamp? timestamp,
    String? customerid,
    String? customerType,
    String? customerFileUrl,
    String? fileName,
  }) {
    return Customer(
      customerName: customerName ?? this.customerName,
      ticketId: ticketId ?? this.ticketId,
      deviceType: deviceType ?? this.deviceType,
      deviceBrand: deviceBrand ?? this.deviceBrand,
      deviceCondition: deviceCondition ?? this.deviceCondition,
      issueDescription: issueDescription ?? this.issueDescription,
      address: address ?? this.address,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      jobType: jobType ?? this.jobType,
      amount: amount ?? this.amount,
      deviceName: deviceName ?? this.deviceName,
      problem: problem ?? this.problem,
      assignedEngineer: assignedEngineer ?? this.assignedEngineer,
      timestamp: timestamp ?? this.timestamp,
      customerid: customerid ?? this.customerid,
      customerType: customerType ?? this.customerType,
      customerFileUrl: customerFileUrl ?? this.customerFileUrl,
      fileName: fileName ?? this.fileName,
    );
  }

  // Convert Customer to Firestore map
  Map<String, dynamic> toMap() {
    return {
      "customerName": customerName,
      "ticketId": ticketId,
      "deviceType": deviceType,
      "deviceBrand": deviceBrand,
      "deviceCondition": deviceCondition,
      "issueDescription": issueDescription,
      "address": address,
      "mobileNumber": mobileNumber,
      "JobType": jobType,
      "paymentDetails": amount, // Include paymentDetails in the map
      "DeviceName": deviceName,
      "Problem": problem,
      "assignedEngineer": assignedEngineer,
      "createdAt": timestamp,
      "customerType": customerType,
      "customerFileUrl": customerFileUrl,
      "fileName": fileName,
    };
  }

  // Convert Firestore document to Customer object
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // Debug: Print the data fetched from Firestore
    print("Fetched data from Firestore: $data");

    return Customer(
      customerName: data?['customerName'] ?? '',
      ticketId: data?['ticketId'] ?? data?['bookingId'] ?? '',
      deviceType: data?['deviceType'] ?? '',
      deviceBrand: data?['deviceBrand'] ?? '',
      deviceCondition: data?['deviceCondition'] ?? '',
      issueDescription: data?['issueDescription'] ?? data?['message'] ?? '',
      address: data?['address'] ?? '',
      mobileNumber: data?['mobileNumber'] ?? "",
      jobType: data?['JobType'] ?? '',
      amount:
          data?['paymentDetails']?.toString() ??
          data?['amount']?.toString() ??
          '', // Handle paymentDetails from Firestore
      deviceName: data?['DeviceName'] ?? '',
      problem: data?['Problem'] ?? '',
      assignedEngineer:
          data?['assignedEngineer'] ?? data?['AssignedEngineer'] ?? '',
      timestamp: _parseTimestamp(data?['createdAt'] ?? data?['timestamp']),
      customerid: data?['id'] ?? data?['customerId'] ?? data?['customerid'] ?? '',
      customerType: data?['customerType']?.toString() ?? data?['customer_type']?.toString() ?? '',
      customerFileUrl: data?['customerFileUrl'],
      fileName: data?['fileName'],
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
  String get bookingId => ticketId;
  String get message => issueDescription;

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
Ticket ID: $ticketId
Device Type: $deviceType
Device Brand: $deviceBrand
Device Condition: $deviceCondition
Issue Description: $issueDescription
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
