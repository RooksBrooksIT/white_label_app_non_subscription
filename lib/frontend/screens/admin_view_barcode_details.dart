import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AdminViewBarcodeDetails extends StatefulWidget {
  const AdminViewBarcodeDetails({super.key});

  @override
  State<AdminViewBarcodeDetails> createState() =>
      _AdminViewBarcodeDetailsState();
}

class _AdminViewBarcodeDetailsState extends State<AdminViewBarcodeDetails> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _barcodeData = [];
  List<Map<String, dynamic>> _filteredData = [];
  final Set<String> _expandedItems = {};
  final Set<String> _editingItems = {};
  final Map<String, Map<String, TextEditingController>> _editingControllers =
      {};
  final Map<String, TextEditingController> _dateControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchBarcodeData();
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all editing controllers
    for (var controllers in _editingControllers.values) {
      for (var controller in controllers.values) {
        controller.dispose();
      }
    }
    for (var controller in _dateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';

    try {
      // Handle Firestore Timestamp
      if (dateValue is Timestamp) {
        final date = dateValue.toDate();
        return DateFormat('dd/MM/yyyy').format(date);
      }

      // Handle DateTime
      if (dateValue is DateTime) {
        return DateFormat('dd/MM/yyyy').format(dateValue);
      }

      // Handle string representation
      if (dateValue is String) {
        // Try to parse as DateTime first
        final date = DateTime.tryParse(dateValue);
        if (date != null) {
          return DateFormat('dd/MM/yyyy').format(date);
        }

        // Handle Firestore Timestamp string format
        if (dateValue.contains('Timestamp')) {
          final timestamp = RegExp(
            r'seconds: (\d+), nanoseconds: \d+',
          ).firstMatch(dateValue);
          if (timestamp != null) {
            final seconds = int.parse(timestamp.group(1)!);
            final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            return DateFormat('dd/MM/yyyy').format(date);
          }
        }

        // If it's already in DD/MM/YYYY format, return as is
        if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dateValue)) {
          return dateValue;
        }
      }

      return dateValue.toString();
    } catch (e) {
      return dateValue.toString();
    }
  }

  DateTime? _parseDate(String dateString) {
    if (dateString.isEmpty) return null;

    try {
      // Parse DD/MM/YYYY format
      if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dateString)) {
        final parts = dateString.split('/');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }

      // Try other common formats
      return DateTime.tryParse(dateString);
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchBarcodeData() async {
    try {
      final querySnapshot = await FirestoreService.instance
          .collection('Barcode_Scanning_Details')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _barcodeData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['documentId'] = doc.id;

          // Format all date fields to DD/MM/YYYY
          data['formattedCreatedAt'] = _formatDate(data['createdAt']);
          data['formattedCurrentDate'] = _formatDate(data['currentDate']);
          data['formattedWarrantyStart'] = _formatDate(
            data['warrantyStartDate'],
          );
          data['formattedWarrantyEnd'] = _formatDate(data['warrantyEndDate']);

          return data;
        }).toList();
        _filteredData = _barcodeData;
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching data: $e');
    }
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredData = _barcodeData;
      } else {
        _filteredData = _barcodeData.where((item) {
          return item['barcode']!.toString().toLowerCase().contains(query) ||
              item['customerName']!.toString().toLowerCase().contains(query) ||
              item['customerId']!.toString().toLowerCase().contains(query) ||
              item['productName']!.toString().toLowerCase().contains(query) ||
              item['brandName']!.toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _toggleExpand(String documentId) {
    setState(() {
      if (_expandedItems.contains(documentId)) {
        _expandedItems.remove(documentId);
      } else {
        _expandedItems.add(documentId);
      }
    });
  }

  void _startEditing(String documentId, Map<String, dynamic> data) {
    setState(() {
      _editingItems.add(documentId);
      _initializeControllers(documentId, data);
    });
  }

  void _initializeControllers(String documentId, Map<String, dynamic> data) {
    if (!_editingControllers.containsKey(documentId)) {
      _editingControllers[documentId] = {
        'modelNumber': TextEditingController(
          text: data['modelNumber']?.toString() ?? '',
        ),
        'serialNumber': TextEditingController(
          text: data['serialNumber']?.toString() ?? '',
        ),
      };
    }

    // Initialize date controllers with formatted dates (DD/MM/YYYY)
    _dateControllers['${documentId}_start'] = TextEditingController(
      text: data['formattedWarrantyStart'] ?? '',
    );
    _dateControllers['${documentId}_end'] = TextEditingController(
      text: data['formattedWarrantyEnd'] ?? '',
    );
  }

  void _cancelEditing(String documentId) {
    setState(() {
      _editingItems.remove(documentId);
    });
  }

  Future<void> _saveChanges(
    String documentId,
    Map<String, dynamic> originalData,
  ) async {
    try {
      final controllers = _editingControllers[documentId];
      if (controllers == null) return;

      // Parse dates from DD/MM/YYYY format to DateTime
      final warrantyStartDate = _parseDate(
        _dateControllers['${documentId}_start']!.text,
      );
      final warrantyEndDate = _parseDate(
        _dateControllers['${documentId}_end']!.text,
      );

      if (warrantyStartDate == null || warrantyEndDate == null) {
        _showErrorSnackBar('Please enter valid dates in DD/MM/YYYY format');
        return;
      }

      final updatedData = {
        'modelNumber': controllers['modelNumber']!.text,
        'serialNumber': controllers['serialNumber']!.text,
        'warrantyStartDate': Timestamp.fromDate(warrantyStartDate),
        'warrantyEndDate': Timestamp.fromDate(warrantyEndDate),
      };

      await FirestoreService.instance
          .collection('Barcode_Scanning_Details')
          .doc(documentId)
          .update(updatedData);

      setState(() {
        _editingItems.remove(documentId);

        // Update local data with new values and formatted dates
        final index = _barcodeData.indexWhere(
          (item) => item['documentId'] == documentId,
        );
        if (index != -1) {
          // Update the fields that were changed
          _barcodeData[index]['modelNumber'] = controllers['modelNumber']!.text;
          _barcodeData[index]['serialNumber'] =
              controllers['serialNumber']!.text;
          _barcodeData[index]['warrantyStartDate'] = Timestamp.fromDate(
            warrantyStartDate,
          );
          _barcodeData[index]['warrantyEndDate'] = Timestamp.fromDate(
            warrantyEndDate,
          );

          // Update formatted dates
          _barcodeData[index]['formattedWarrantyStart'] =
              _dateControllers['${documentId}_start']!.text;
          _barcodeData[index]['formattedWarrantyEnd'] =
              _dateControllers['${documentId}_end']!.text;
        }
        _filterData(); // Refresh filtered data
      });

      _showSuccessSnackBar('Data updated successfully');
    } catch (e) {
      _showErrorSnackBar('Error updating data: $e');
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    // Parse current date if exists, otherwise use today
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      final parsedDate = _parseDate(controller.text);
      if (parsedDate != null) {
        initialDate = parsedDate;
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      // Format as DD/MM/YYYY
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEditableField({
    required String documentId,
    required String fieldName,
    required String label,
    required bool isEditing,
    required Map<String, dynamic> data,
    bool isDateField = false,
  }) {
    if (isEditing) {
      if (isDateField) {
        final controller =
            _dateControllers['${documentId}_${fieldName == 'warrantyStartDate' ? 'start' : 'end'}'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'DD/MM/YYYY',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today, size: 20),
                  onPressed: () => _selectDate(context, controller!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      } else {
        final controller = _editingControllers[documentId]?[fieldName];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter $label',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }
    } else {
      String displayValue = 'N/A';

      if (isDateField) {
        // Use formatted dates for display
        if (fieldName == 'warrantyStartDate') {
          displayValue = data['formattedWarrantyStart'] ?? 'N/A';
        } else if (fieldName == 'warrantyEndDate') {
          displayValue = data['formattedWarrantyEnd'] ?? 'N/A';
        }
      } else {
        displayValue = data[fieldName]?.toString() ?? 'N/A';
      }

      return _buildDetailRow(label: label, value: displayValue);
    }
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
    Map<String, dynamic> data,
    String documentId,
    bool isExpanded,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Barcode Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['barcode']?.toString() ?? 'N/A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${data['customerName'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),

                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'User Log: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      TextSpan(
                        text: data['userlog'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color.fromARGB(255, 7, 110, 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Expand Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => _toggleExpand(documentId),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Barcode Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search barcode, customer, product...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
            ),
          ),
          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              'Found ${_filteredData.length} records',
              style: TextStyle(
                color:
                    Theme.of(context).textTheme.bodyMedium?.color ??
                    Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Results
          Expanded(
            child: _filteredData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No records found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search terms',
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredData.length,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final data = _filteredData[index];
                      final documentId = data['documentId']?.toString() ?? '';
                      final isExpanded = _expandedItems.contains(documentId);
                      final isEditing = _editingItems.contains(documentId);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Header Section
                              _buildHeaderSection(data, documentId, isExpanded),
                              // Expandable Section
                              if (isExpanded) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      // Product Information Section
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Product Information',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDetailRow(
                                        label: 'Product Name',
                                        value:
                                            data['productName']?.toString() ??
                                            'N/A',
                                      ),
                                      _buildDetailRow(
                                        label: 'Brand Name',
                                        value:
                                            data['brandName']?.toString() ??
                                            'N/A',
                                      ),
                                      _buildDetailRow(
                                        label: 'Customer Phone',
                                        value:
                                            data['customerPhone']?.toString() ??
                                            'N/A',
                                      ),

                                      const SizedBox(height: 20),
                                      const Divider(),
                                      const SizedBox(height: 8),

                                      // Dates Section
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Date Information',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDetailRow(
                                        label: 'Created At',
                                        value:
                                            data['formattedCreatedAt'] ?? 'N/A',
                                      ),
                                      _buildDetailRow(
                                        label: 'Current Date',
                                        value:
                                            data['formattedCurrentDate'] ??
                                            'N/A',
                                      ),
                                      _buildDetailRow(
                                        label: 'Warranty Start',
                                        value:
                                            data['formattedWarrantyStart'] ??
                                            'N/A',
                                      ),
                                      _buildDetailRow(
                                        label: 'Warranty End',
                                        value:
                                            data['formattedWarrantyEnd'] ??
                                            'N/A',
                                      ),

                                      const SizedBox(height: 20),
                                      const Divider(),
                                      const SizedBox(height: 8),

                                      // Editable Section
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Product Details (Editable)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Editable fields
                                      _buildEditableField(
                                        documentId: documentId,
                                        fieldName: 'modelNumber',
                                        label: 'Model Number',
                                        isEditing: isEditing,
                                        data: data,
                                      ),
                                      _buildEditableField(
                                        documentId: documentId,
                                        fieldName: 'serialNumber',
                                        label: 'Serial Number',
                                        isEditing: isEditing,
                                        data: data,
                                      ),
                                      _buildEditableField(
                                        documentId: documentId,
                                        fieldName: 'warrantyStartDate',
                                        label: 'Warranty Start Date',
                                        isEditing: isEditing,
                                        data: data,
                                        isDateField: true,
                                      ),
                                      _buildEditableField(
                                        documentId: documentId,
                                        fieldName: 'warrantyEndDate',
                                        label: 'Warranty End Date',
                                        isEditing: isEditing,
                                        data: data,
                                        isDateField: true,
                                      ),

                                      const SizedBox(height: 20),

                                      // Action Buttons
                                      Container(
                                        padding: const EdgeInsets.only(top: 16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (!isEditing)
                                              ElevatedButton.icon(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Edit Details',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.orange,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                ),
                                                onPressed: () => _startEditing(
                                                  documentId,
                                                  data,
                                                ),
                                              ),
                                            if (isEditing) ...[
                                              ElevatedButton.icon(
                                                icon: const Icon(
                                                  Icons.cancel,
                                                  size: 18,
                                                ),
                                                label: const Text('Cancel'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.grey,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                ),
                                                onPressed: () =>
                                                    _cancelEditing(documentId),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                icon: const Icon(
                                                  Icons.save,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Save Changes',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                ),
                                                onPressed: () => _saveChanges(
                                                  documentId,
                                                  data,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
