import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/brand_model_backend.dart';

class BrandModelPage extends StatefulWidget {
  const BrandModelPage({super.key});

  @override
  State<BrandModelPage> createState() => _BrandModelPageState();
}

class _BrandModelPageState extends State<BrandModelPage> {
  Color get primaryColor => Theme.of(context).primaryColor;
  Color get errorColor => Theme.of(context).colorScheme.error;
  Color get successColor => Colors.green;
  Color get lightTextColor => Theme.of(context).hintColor;

  final BrandModelBackend _backend = BrandModelBackend();
  bool isLoading = false;

  // ────────────────────────────────────────────
  // Delete
  // ────────────────────────────────────────────
  Future<void> _deleteItem(String docId, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Device',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Delete "$deviceName"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await _backend.deleteDeviceItem('Devices', docId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$deviceName" deleted'),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  // ────────────────────────────────────────────
  // Open bottom sheet form  (add OR edit)
  // ────────────────────────────────────────────
  void _openForm({Map<String, dynamic>? existing, String? editDocId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeviceFormSheet(
        primaryColor: primaryColor,
        errorColor: errorColor,
        successColor: successColor,
        backend: _backend,
        existingData: existing,
        editDocId: editDocId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // ── AppBar ──────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
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
          'Devices',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
      ),
      // ── Body: Live device list ───────────────
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))
          : StreamBuilder<QuerySnapshot>(
              stream: _backend.streamDevices('Devices'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _centeredMessage(
                      Icons.error_outline_rounded,
                      'Error loading devices',
                      snapshot.error.toString(),
                      iconColor: errorColor);
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(primaryColor)),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                return CustomScrollView(
                  slivers: [
                    // ── Header info bar ────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Devices',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${docs.length} Device${docs.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Empty state ────────────
                    if (docs.isEmpty)
                      SliverFillRemaining(
                        child: _centeredMessage(
                          Icons.devices_outlined,
                          'No Devices Yet',
                          'Tap "+ Add New Device" below\nto save your first device.',
                        ),
                      ),

                    // ── Device cards ───────────
                    if (docs.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final doc = docs[i];
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final deviceName =
                                  data['deviceName'] ?? 'Unknown Device';
                              final brand = data['brandName'] ?? 'N/A';
                              final model = data['model'] ?? 'N/A';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(13),
                                    ),
                                    child: Icon(Icons.devices_rounded,
                                        color: primaryColor, size: 22),
                                  ),
                                  title: Text(
                                    deviceName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Text(
                                        '$brand · $model',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'ID: ${doc.id}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_rounded,
                                            color: primaryColor, size: 20),
                                        onPressed: () => _openForm(
                                            existing: data,
                                            editDocId: doc.id),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: errorColor,
                                            size: 20),
                                        onPressed: () =>
                                            _deleteItem(doc.id, deviceName),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: docs.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

      // ── CTA: Add New Device button ───────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Add New Device',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: primaryColor.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centeredMessage(
    IconData icon,
    String title,
    String subtitle, {
    Color? iconColor,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 60,
              color: iconColor ?? lightTextColor.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// Bottom Sheet Form — Add / Edit Device
// ══════════════════════════════════════════════════
class _DeviceFormSheet extends StatefulWidget {
  final Color primaryColor;
  final Color errorColor;
  final Color successColor;
  final BrandModelBackend backend;
  final Map<String, dynamic>? existingData;
  final String? editDocId;

  const _DeviceFormSheet({
    required this.primaryColor,
    required this.errorColor,
    required this.successColor,
    required this.backend,
    this.existingData,
    this.editDocId,
  });

  @override
  State<_DeviceFormSheet> createState() => _DeviceFormSheetState();
}

class _DeviceFormSheetState extends State<_DeviceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deviceNameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _specCtrl;
  late final TextEditingController _descCtrl;

  bool _isSaving = false;
  bool get isEditing => widget.editDocId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    _deviceNameCtrl =
        TextEditingController(text: d?['deviceName'] ?? '');
    _brandCtrl = TextEditingController(text: d?['brandName'] ?? '');
    _modelCtrl = TextEditingController(text: d?['model'] ?? '');
    _specCtrl =
        TextEditingController(text: d?['specification'] ?? '');
    _descCtrl =
        TextEditingController(text: d?['description'] ?? '');
  }

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _specCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      await widget.backend.saveDeviceEntry(
        deviceName: _deviceNameCtrl.text.trim(),
        brandName: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        specification: _specCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        editingDocumentId: isEditing ? widget.editDocId : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close sheet
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Device ${isEditing ? 'updated' : 'added'} successfully'),
        backgroundColor: widget.successColor,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: widget.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  InputDecoration _dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
          color: widget.primaryColor, fontWeight: FontWeight.w600),
      hintStyle:
          const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon,
          color: widget.primaryColor.withValues(alpha: 0.7), size: 20),
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
        borderSide: BorderSide(color: widget.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.errorColor, width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── drag handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // ── title row ────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.edit_rounded
                          : Icons.add_rounded,
                      color: widget.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Device' : 'Add New Device',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isEditing
                            ? 'Update device details'
                            : 'Saved to: Devices / deviceName_date',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.primaryColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Device Name ────────────────
              const _FieldLabel('DEVICE NAME'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _deviceNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A)),
                decoration: _dec('Device Name',
                    'e.g., Laptop, Printer, Desktop...', Icons.devices_other_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Device name is required'
                    : null,
              ),
              const SizedBox(height: 6),
              // Doc ID hint chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: Color(0xFF16A34A)),
                    SizedBox(width: 5),
                    Text(
                      'Document ID → devicename_YYYY-MM-DD',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Details ────────────────────
              const _FieldLabel('DEVICE DETAILS'),
              const SizedBox(height: 8),

              TextFormField(
                controller: _brandCtrl,
                decoration: _dec('Brand Name', 'e.g., Dell, HP, Canon...',
                    Icons.branding_watermark_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Brand name is required'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _modelCtrl,
                decoration: _dec('Model', 'e.g., XPS 15, LaserJet Pro...',
                    Icons.model_training_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Model is required'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _specCtrl,
                maxLines: 2,
                decoration: _dec('Specification',
                    'e.g., i7, 16GB RAM, 512GB SSD...', Icons.list_alt_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Specification is required'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: _dec('Description',
                    'Additional details about this device...',
                    Icons.description_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 22),

              // ── Save button ──────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(
                          isEditing
                              ? Icons.save_rounded
                              : Icons.add_rounded,
                          size: 20),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : isEditing
                            ? 'Update Device'
                            : 'Save to Devices',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Cancel button ─────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      );
}
