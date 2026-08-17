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
  // ── Theme helpers ─────────────────────────────
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;

  // ── State ─────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _barcodeData = [];
  List<Map<String, dynamic>> _filteredData = [];
  final Set<String> _expandedItems = {};
  final Set<String> _editingItems = {};
  final Map<String, Map<String, TextEditingController>> _editingControllers =
      {};
  final Map<String, TextEditingController> _dateControllers = {};
  bool _isLoading = true;

  // ── Init / Dispose ────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchBarcodeData();
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var ctrlMap in _editingControllers.values) {
      for (var c in ctrlMap.values) {
        c.dispose();
      }
    }
    for (var c in _dateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Date helpers ──────────────────────────────
  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    try {
      if (d is Timestamp) return DateFormat('dd/MM/yyyy').format(d.toDate());
      if (d is DateTime) return DateFormat('dd/MM/yyyy').format(d);
      if (d is String) {
        final dt = DateTime.tryParse(d);
        if (dt != null) return DateFormat('dd/MM/yyyy').format(dt);
        if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(d)) return d;
      }
      return d.toString();
    } catch (_) {
      return d.toString();
    }
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(s)) {
        final p = s.split('/');
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  // ── Fetch & filter ────────────────────────────
  Future<void> _fetchBarcodeData() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirestoreService.instance
          .collection('Barcode_Scanning_Details')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _barcodeData = snap.docs.map((doc) {
          final d = doc.data();
          d['documentId'] = doc.id;
          d['formattedCreatedAt'] = _formatDate(d['createdAt']);
          d['formattedCurrentDate'] = _formatDate(d['currentDate']);
          d['formattedWarrantyStart'] = _formatDate(d['warrantyStartDate']);
          d['formattedWarrantyEnd'] = _formatDate(d['warrantyEndDate']);
          return d;
        }).toList();
        _filteredData = _barcodeData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Error fetching data: $e', isError: true);
    }
  }

  void _filterData() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredData = q.isEmpty
          ? _barcodeData
          : _barcodeData.where((item) {
              return (item['barcode']?.toString().toLowerCase() ?? '')
                      .contains(q) ||
                  (item['customerName']?.toString().toLowerCase() ?? '')
                      .contains(q) ||
                  (item['customerId']?.toString().toLowerCase() ?? '')
                      .contains(q) ||
                  (item['productName']?.toString().toLowerCase() ?? '')
                      .contains(q) ||
                  (item['brandName']?.toString().toLowerCase() ?? '')
                      .contains(q);
            }).toList();
    });
  }

  // ── Expand / Edit helpers ─────────────────────
  void _toggleExpand(String id) => setState(() {
        _expandedItems.contains(id)
            ? _expandedItems.remove(id)
            : _expandedItems.add(id);
      });

  void _startEditing(String id, Map<String, dynamic> data) {
    setState(() {
      _editingItems.add(id);
      _editingControllers[id] ??= {
        'modelNumber': TextEditingController(
            text: data['modelNumber']?.toString() ?? ''),
        'serialNumber': TextEditingController(
            text: data['serialNumber']?.toString() ?? ''),
      };
      _dateControllers['${id}_start'] = TextEditingController(
          text: data['formattedWarrantyStart'] ?? '');
      _dateControllers['${id}_end'] = TextEditingController(
          text: data['formattedWarrantyEnd'] ?? '');
    });
  }

  void _cancelEditing(String id) =>
      setState(() => _editingItems.remove(id));

  Future<void> _saveChanges(String id, Map<String, dynamic> original) async {
    final ctrls = _editingControllers[id];
    if (ctrls == null) return;

    final startDate = _parseDate(_dateControllers['${id}_start']!.text);
    final endDate = _parseDate(_dateControllers['${id}_end']!.text);

    if (startDate == null || endDate == null) {
      _snack('Enter valid dates in DD/MM/YYYY format', isError: true);
      return;
    }

    try {
      await FirestoreService.instance
          .collection('Barcode_Scanning_Details')
          .doc(id)
          .update({
        'modelNumber': ctrls['modelNumber']!.text,
        'serialNumber': ctrls['serialNumber']!.text,
        'warrantyStartDate': Timestamp.fromDate(startDate),
        'warrantyEndDate': Timestamp.fromDate(endDate),
      });

      setState(() {
        _editingItems.remove(id);
        final idx = _barcodeData.indexWhere((i) => i['documentId'] == id);
        if (idx != -1) {
          _barcodeData[idx]['modelNumber'] = ctrls['modelNumber']!.text;
          _barcodeData[idx]['serialNumber'] = ctrls['serialNumber']!.text;
          _barcodeData[idx]['warrantyStartDate'] =
              Timestamp.fromDate(startDate);
          _barcodeData[idx]['warrantyEndDate'] =
              Timestamp.fromDate(endDate);
          _barcodeData[idx]['formattedWarrantyStart'] =
              _dateControllers['${id}_start']!.text;
          _barcodeData[idx]['formattedWarrantyEnd'] =
              _dateControllers['${id}_end']!.text;
        }
        _filterData();
      });
      _snack('Record updated successfully');
    } catch (e) {
      _snack('Error updating: $e', isError: true);
    }
  }

  Future<void> _selectDate(
      BuildContext ctx, TextEditingController ctrl) async {
    DateTime initial = DateTime.now();
    if (ctrl.text.isNotEmpty) {
      final p = _parseDate(ctrl.text);
      if (p != null) initial = p;
    }
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? errorColor : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // ── AppBar ───────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF1F5F9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Barcode Details',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: _fetchBarcodeData,
              icon: Icon(Icons.refresh_rounded, color: primaryColor),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Search bar ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search barcode, customer, product...',
                hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                prefixIcon:
                    Icon(Icons.search_rounded, color: primaryColor, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          _filterData();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // ── Record count ─────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isLoading
                      ? 'Loading...'
                      : '${_filteredData.length} Record${_filteredData.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B)),
                ),
                if (!_isLoading && _barcodeData.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total: ${_barcodeData.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor),
                    ),
                  ),
              ],
            ),
          ),

          // ── List ─────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(primaryColor)),
                  )
                : _filteredData.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filteredData.length,
                        itemBuilder: (ctx, i) =>
                            _buildCard(_filteredData[i]),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 60,
              color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
          const SizedBox(height: 14),
          const Text('No records found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569))),
          const SizedBox(height: 6),
          const Text('Try adjusting your search terms',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ── Barcode record card ───────────────────────
  Widget _buildCard(Map<String, dynamic> data) {
    final id = data['documentId']?.toString() ?? '';
    final isExpanded = _expandedItems.contains(id);
    final isEditing = _editingItems.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────
          _buildCardHeader(data, id, isExpanded),

          // ── Expanded detail ─────────────────
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product info
                  _sectionHeader(
                      Icons.inventory_2_rounded, 'Product Information',
                      color: primaryColor),
                  const SizedBox(height: 10),
                  _infoRow(Icons.shopping_bag_rounded, 'Product Name',
                      data['productName']?.toString() ?? 'N/A'),
                  _infoRow(Icons.branding_watermark_rounded, 'Brand Name',
                      data['brandName']?.toString() ?? 'N/A'),
                  _infoRow(Icons.phone_rounded, 'Customer Phone',
                      data['customerPhone']?.toString() ?? 'N/A'),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Date info
                  _sectionHeader(
                      Icons.calendar_today_rounded, 'Date Information',
                      color: Colors.teal),
                  const SizedBox(height: 10),
                  _infoRow(Icons.add_circle_outline_rounded, 'Created At',
                      data['formattedCreatedAt'] ?? 'N/A'),
                  _infoRow(Icons.today_rounded, 'Current Date',
                      data['formattedCurrentDate'] ?? 'N/A'),
                  _infoRow(Icons.event_available_rounded, 'Warranty Start',
                      data['formattedWarrantyStart'] ?? 'N/A'),
                  _infoRow(Icons.event_busy_rounded, 'Warranty End',
                      data['formattedWarrantyEnd'] ?? 'N/A'),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Editable section
                  _sectionHeader(Icons.edit_rounded, 'Editable Details',
                      color: const Color(0xFFF59E0B)),
                  const SizedBox(height: 10),

                  _buildEditableField(
                      id: id,
                      fieldName: 'modelNumber',
                      label: 'Model Number',
                      isEditing: isEditing,
                      data: data),
                  _buildEditableField(
                      id: id,
                      fieldName: 'serialNumber',
                      label: 'Serial Number',
                      isEditing: isEditing,
                      data: data),
                  _buildEditableField(
                      id: id,
                      fieldName: 'warrantyStartDate',
                      label: 'Warranty Start Date',
                      isEditing: isEditing,
                      data: data,
                      isDateField: true),
                  _buildEditableField(
                      id: id,
                      fieldName: 'warrantyEndDate',
                      label: 'Warranty End Date',
                      isEditing: isEditing,
                      data: data,
                      isDateField: true),

                  const SizedBox(height: 8),

                  // Action buttons
                  if (!isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _startEditing(id, data),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit Details',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(
                              color: Color(0xFFF59E0B), width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelEditing(id),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Cancel',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(
                                  color: Color(0xFFE2E8F0)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _saveChanges(id, data),
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: const Text('Save Changes',
                                style:
                                    TextStyle(fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Card header row ───────────────────────────
  Widget _buildCardHeader(
      Map<String, dynamic> data, String id, bool isExpanded) {
    return InkWell(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      onTap: () => _toggleExpand(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child:
                  Icon(Icons.qr_code_rounded, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['barcode']?.toString() ?? 'N/A',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data['customerName']?.toString() ?? 'Unknown Customer',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B)),
                  ),
                  if ((data['userlog'] ?? '').isNotEmpty)
                    Row(
                      children: [
                        const Text('Log: ',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          data['userlog'] ?? '',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: primaryColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────
  Widget _sectionHeader(IconData icon, String title, {required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.1)),
      ],
    );
  }

  // ── Info row ───────────────────────────────────
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 15,
              color: primaryColor.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8))),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  // ── Editable / read-only field ─────────────────
  Widget _buildEditableField({
    required String id,
    required String fieldName,
    required String label,
    required bool isEditing,
    required Map<String, dynamic> data,
    bool isDateField = false,
  }) {
    if (isEditing) {
      if (isDateField) {
        final ctrl = _dateControllers[
            '${id}_${fieldName == 'warrantyStartDate' ? 'start' : 'end'}'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: ctrl,
            readOnly: true,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                  color: primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              hintText: 'DD/MM/YYYY',
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today_rounded,
                    size: 18, color: primaryColor),
                onPressed: () => _selectDate(context, ctrl!),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        );
      } else {
        final ctrl = _editingControllers[id]?[fieldName];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: ctrl,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                  color: primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              hintText: 'Enter $label',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        );
      }
    } else {
      // Read-only view
      String val = 'N/A';
      if (isDateField) {
        val = fieldName == 'warrantyStartDate'
            ? data['formattedWarrantyStart'] ?? 'N/A'
            : data['formattedWarrantyEnd'] ?? 'N/A';
      } else {
        val = data[fieldName]?.toString() ?? 'N/A';
      }
      return _infoRow(
          isDateField
              ? Icons.calendar_today_rounded
              : Icons.info_outline_rounded,
          label,
          val);
    }
  }
}
