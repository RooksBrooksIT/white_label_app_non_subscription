import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_deliverytickets_screen.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_var_data_screen.dart';

class AssigndeliveryCustomerPage extends StatefulWidget {
  final Customer customer;

  const AssigndeliveryCustomerPage({super.key, required this.customer});

  @override
  _AssigndeliveryCustomerPageState createState() =>
      _AssigndeliveryCustomerPageState();
}

class _AssigndeliveryCustomerPageState
    extends State<AssigndeliveryCustomerPage> {
  bool _isAssigning = false;
  bool _isEngineerSelected = true;
  String? _selectedHelper;
  final TextEditingController _reasonController = TextEditingController();
  bool _showHelperInputs = false;

  List<Map<String, String>> addedHelpers = [];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assign Engineer For Delivery',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isEngineerSelected = true;
                        _showHelperInputs = false;
                        _selectedHelper = null;
                        _reasonController.clear();
                        addedHelpers.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEngineerSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).disabledColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Engineer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isEngineerSelected = false;
                        _showHelperInputs = true;
                        _selectedHelper = null;
                        _reasonController.clear();
                        addedHelpers.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isEngineerSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).disabledColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Helper',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _isEngineerSelected ? _buildEngineerView() : _buildHelperView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngineerView() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  widget.customer.customerName.isNotEmpty
                      ? widget.customer.customerName[0]
                      : '?',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                widget.customer.customerName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: Theme.of(context).dividerColor, thickness: 1),
            const SizedBox(height: 10),
            _buildDetailRow('Booking ID', widget.customer.bookingId),
            _buildDetailRow('Message', widget.customer.message),
            _buildDetailRow('Address', widget.customer.address),
            _buildDetailRow('Contact Number', widget.customer.mobileNumber),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isAssigning
                    ? null
                    : () => _showEmployeeSelection(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isAssigning
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                      )
                    : const Text(
                        'Assign Engineer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelperView() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirestoreService.instance
          .collection('Admin_details')
          .doc(widget.customer.bookingId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final assignedEmployee = data['assignedEmployee'] as String? ?? '';

        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                assignedEmployee.isNotEmpty
                    ? _buildDetailRow('Assigned Employee', assignedEmployee)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Message', widget.customer.message),
                        ],
                      ),
                const SizedBox(height: 20),
                const Text(
                  'Select Helper',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.instance
                      .collection('EngineerLogin')
                      .snapshots(),
                  builder: (context, engineerSnapshot) {
                    if (engineerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (engineerSnapshot.hasError) {
                      return Text('Error: ${engineerSnapshot.error}');
                    }
                    final engineerDocs = engineerSnapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedHelper,
                      hint: const Text('Select Helper'),
                      items: engineerDocs.map((doc) {
                        final data = doc.data();
                        if (data is Map<String, dynamic>) {
                          final username = data['Username'] ?? '';
                          return DropdownMenuItem<String>(
                            value: username,
                            child: Text(username),
                          );
                        }
                        return const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Unknown'),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedHelper = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if ((_selectedHelper != null &&
                              _selectedHelper!.isNotEmpty) &&
                          _reasonController.text.trim().isNotEmpty) {
                        setState(() {
                          addedHelpers.add({
                            'helperName': _selectedHelper!,
                            'reason': _reasonController.text.trim(),
                          });
                          _selectedHelper = null;
                          _reasonController.clear();
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select a helper and enter a reason',
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Add Helper',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ...addedHelpers.map((helper) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Helper Name: ${helper['helperName']}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Reason: ${helper['reason']}'),
                        ],
                      ),
                    ),
                  );
                }),
                if (addedHelpers.isNotEmpty)
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final docRef = FirestoreService.instance
                              .collection('Admin_details')
                              .doc(widget.customer.bookingId);
                          final snapshot = await docRef.get();

                          final existingData = snapshot.data() ?? {};

                          int maxIndex = 0;
                          existingData.forEach((key, value) {
                            final match = RegExp(
                              r'^Helper(\d+)$',
                            ).firstMatch(key);
                            if (match != null) {
                              final index =
                                  int.tryParse(match.group(1) ?? '') ?? 0;
                              if (index > maxIndex) maxIndex = index;
                            }
                          });

                          Map<String, dynamic> fieldsToUpdate = {};

                          for (int i = 0; i < addedHelpers.length; i++) {
                            final index = maxIndex + i + 1;
                            fieldsToUpdate['Helper$index'] =
                                addedHelpers[i]['helperName'] ?? '';
                            fieldsToUpdate['Helper${index}_Reason'] =
                                addedHelpers[i]['reason'] ?? '';
                          }

                          await docRef.set(
                            fieldsToUpdate,
                            SetOptions(merge: true),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Helpers added successfully'),
                            ),
                          );

                          setState(() {
                            addedHelpers.clear();
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving helpers: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select an Engineer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey),
              SizedBox(
                height: 250,
                child: FutureBuilder<QuerySnapshot>(
                  future: FirestoreService.instance
                      .collection('EngineerLogin')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No engineers found.'));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        if (data is Map<String, dynamic>) {
                          final username = data['Username'] ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                username.isNotEmpty ? username[0] : '?',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            title: Text(username),
                            onTap: () async {
                              Navigator.pop(context);
                              await _assignEngineerToCustomer(username);
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _assignEngineerToCustomer(String engineerName) async {
    setState(() => _isAssigning = true);
    try {
      await FirestoreService.instance
          .collection('Admin_details')
          .doc(widget.customer.bookingId)
          .set({
            'id': widget.customer.customerid,
            'assignedEmployee': engineerName,
            'customerName': widget.customer.customerName,
            'bookingId': widget.customer.bookingId,
            'deviceType': widget.customer.deviceType,
            'deviceBrand': widget.customer.deviceBrand,
            'deviceCondition': widget.customer.deviceCondition,
            'message': widget.customer.message,
            'address': widget.customer.address,
            'notificationStatus': 'pending',
            'engineerStatus': 'Assigned',
            'timestamp': FieldValue.serverTimestamp(),
            'assignedTimestamp':
                FieldValue.serverTimestamp(), // Added this line
            'mobileNumber': widget.customer.mobileNumber,
          }, SetOptions(merge: true));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmationdeliveryPage(
              customerName: widget.customer.customerName,
              employeeName: engineerName,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign engineer: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }
}

class ConfirmationdeliveryPage extends StatelessWidget {
  final String customerName;
  final String employeeName;

  const ConfirmationdeliveryPage({
    super.key,
    required this.customerName,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirmation',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 120,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$employeeName has been assigned to $customerName.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminDeliveryTickets(statusFilter: ''),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 11, 161, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
