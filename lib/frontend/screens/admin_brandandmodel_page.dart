import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/brand_model_backend.dart';
import '../../utils/responsive_wrapper.dart';

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
  String _sortBy = 'newest';
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 10;

  void _showSortFilterSheet() {
    final searchCtrl = TextEditingController(text: _searchQuery);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sort & Filter Devices',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _sortBy != 'newest')
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _sortBy = 'newest';
                              _currentPage = 1;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by device name, brand, model...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                        _currentPage = 1;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Sort by Newest (Default)'),
                    trailing: _sortBy == 'newest'
                        ? Icon(Icons.check_rounded, color: primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortBy = 'newest';
                        _currentPage = 1;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha_rounded),
                    title: const Text('Sort by Device Name (A-Z)'),
                    trailing: _sortBy == 'name'
                        ? Icon(Icons.check_rounded, color: primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortBy = 'name';
                        _currentPage = 1;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.branding_watermark_outlined),
                    title: const Text('Sort by Brand'),
                    trailing: _sortBy == 'brand'
                        ? Icon(Icons.check_rounded, color: primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortBy = 'brand';
                        _currentPage = 1;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────
  // Delete
  // ────────────────────────────────────────────
  Future<void> _deleteItem(String docId, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Device',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Delete "$deviceName"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$deviceName" deleted'),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                      size: 18,
                    ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Filter & Sort',
            onPressed: _showSortFilterSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ── Body: Live device list ───────────────
      body: ResponsiveWrapper(
        maxWidth: 960,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                stream: _backend.streamDevices('Devices'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _centeredMessage(
                      Icons.error_outline_rounded,
                      'Error loading devices',
                      snapshot.error.toString(),
                      iconColor: errorColor,
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  }

                  var docs = snapshot.data?.docs ?? [];
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['deviceName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final brand = (data['brandName'] ?? '')
                          .toString()
                          .toLowerCase();
                      final model = (data['model'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(q) ||
                          brand.contains(q) ||
                          model.contains(q);
                    }).toList();
                  }

                  if (_sortBy == 'name') {
                    docs = List.from(docs)
                      ..sort((a, b) {
                        final aName =
                            ((a.data() as Map<String, dynamic>)['deviceName'] ??
                                    '')
                                .toString();
                        final bName =
                            ((b.data() as Map<String, dynamic>)['deviceName'] ??
                                    '')
                                .toString();
                        return aName.toLowerCase().compareTo(
                          bName.toLowerCase(),
                        );
                      });
                  } else if (_sortBy == 'brand') {
                    docs = List.from(docs)
                      ..sort((a, b) {
                        final aBrand =
                            ((a.data() as Map<String, dynamic>)['brandName'] ??
                                    '')
                                .toString();
                        final bBrand =
                            ((b.data() as Map<String, dynamic>)['brandName'] ??
                                    '')
                                .toString();
                        return aBrand.toLowerCase().compareTo(
                          bBrand.toLowerCase(),
                        );
                      });
                  }

                  final int totalCount = docs.length;
                  final int totalPages = totalCount == 0
                      ? 1
                      : (totalCount / _pageSize).ceil();

                  if (_currentPage > totalPages) {
                    _currentPage = totalPages;
                  }
                  if (_currentPage < 1) {
                    _currentPage = 1;
                  }

                  final int startIndex = (_currentPage - 1) * _pageSize;
                  final int endIndex = (startIndex + _pageSize > totalCount)
                      ? totalCount
                      : (startIndex + _pageSize);
                  final List<QueryDocumentSnapshot> pagedDocs = docs.isEmpty
                      ? <QueryDocumentSnapshot>[]
                      : docs.sublist(startIndex, endIndex);

                  return Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            // ── Header info bar ────────
                            SliverToBoxAdapter(
                              child: SafeArea(
                                top: false,
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'All Devices',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Equipment & hardware catalog',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$totalCount Device${totalCount == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_searchQuery.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Search: "$_searchQuery"',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _searchQuery = '';
                                                        _currentPage = 1;
                                                      });
                                                    },
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      size: 16,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _openForm(),
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Add New Device',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            elevation: 2,
                                            shadowColor: primaryColor
                                                .withValues(alpha: 0.3),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ── Empty state ────────────
                            if (docs.isEmpty)
                              SliverFillRemaining(
                                child: _centeredMessage(
                                  Icons.devices_outlined,
                                  'No Devices Yet',
                                  _searchQuery.isNotEmpty
                                      ? 'No devices found matching "$_searchQuery".'
                                      : 'Add your first device to configure supported device types.',
                                  showAddButton: true,
                                ),
                              ),

                            // ── Device cards ───────────
                            if (pagedDocs.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    ctx,
                                    i,
                                  ) {
                                    final doc = pagedDocs[i];
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
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        leading: Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.devices_rounded,
                                            color: primaryColor,
                                            size: 22,
                                          ),
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
                                              icon: Icon(
                                                Icons.edit_rounded,
                                                color: primaryColor,
                                                size: 20,
                                              ),
                                              onPressed: () => _openForm(
                                                existing: data,
                                                editDocId: doc.id,
                                              ),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                color: errorColor,
                                                size: 20,
                                              ),
                                              onPressed: () => _deleteItem(
                                                doc.id,
                                                deviceName,
                                              ),
                                              tooltip: 'Delete',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }, childCount: pagedDocs.length),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // ── Fixed bottom pagination footer ──────
                      if (docs.isNotEmpty)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                            child: _buildPaginationFooter(
                              totalCount: totalCount,
                              totalPages: totalPages,
                              startIndex: startIndex,
                              endIndex: endIndex,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int totalCount,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalCount devices',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous button
                OutlinedButton.icon(
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    side: BorderSide(
                      color: _currentPage > 1
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Page numbers
                ..._buildPageNumbers(totalPages),

                const SizedBox(width: 8),
                // Next button
                OutlinedButton.icon(
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text('Next'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    side: BorderSide(
                      color: _currentPage < totalPages
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    final List<Widget> buttons = [];
    final List<int> pages = [];

    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      int start = (_currentPage - 1).clamp(2, totalPages - 3);
      int end = (_currentPage + 1).clamp(4, totalPages - 1);
      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }
      if (!pages.contains(totalPages)) pages.add(totalPages);
    }

    int lastPage = 0;
    for (int p in pages) {
      if (lastPage != 0 && p - lastPage > 1) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      final isSelected = p == _currentPage;
      buttons.add(
        InkWell(
          onTap: () => setState(() => _currentPage = p),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      );
      lastPage = p;
    }

    return buttons;
  }

  Widget _centeredMessage(
    IconData icon,
    String title,
    String subtitle, {
    Color? iconColor,
    bool showAddButton = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 60,
            color: iconColor ?? lightTextColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          if (showAddButton) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                '+ Add New Device',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                elevation: 2,
              ),
            ),
          ],
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

  bool get _isFormValid =>
      _deviceNameCtrl.text.trim().isNotEmpty &&
      _brandCtrl.text.trim().isNotEmpty &&
      _modelCtrl.text.trim().isNotEmpty;

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    _deviceNameCtrl = TextEditingController(
      text: d?['deviceName'] ?? d?['deviceType'] ?? '',
    );
    _brandCtrl = TextEditingController(
      text: d?['brandName'] ?? d?['brand'] ?? '',
    );
    _modelCtrl = TextEditingController(text: d?['model'] ?? '');
    _specCtrl = TextEditingController(text: d?['specification'] ?? '');
    _descCtrl = TextEditingController(text: d?['description'] ?? '');

    _deviceNameCtrl.addListener(_onFieldChanged);
    _brandCtrl.addListener(_onFieldChanged);
    _modelCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _deviceNameCtrl.removeListener(_onFieldChanged);
    _brandCtrl.removeListener(_onFieldChanged);
    _modelCtrl.removeListener(_onFieldChanged);

    _deviceNameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _specCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Device ${isEditing ? 'updated' : 'added'} successfully',
          ),
          backgroundColor: widget.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: widget.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  InputDecoration _dec(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: widget.primaryColor,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(
        icon,
        color: widget.primaryColor.withValues(alpha: 0.7),
        size: 20,
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      isEditing ? Icons.edit_rounded : Icons.add_rounded,
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
              const _FieldLabel('DEVICE NAME *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _deviceNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
                decoration: _dec(
                  'Device Name *',
                  'e.g., Laptop, Printer, Desktop...',
                  Icons.devices_other_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Device name is required'
                    : null,
              ),
              const SizedBox(height: 6),
              // Doc ID hint chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Document ID → devicename_YYYY-MM-DD',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
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
                decoration: _dec(
                  'Brand Name *',
                  'e.g., Dell, HP, Canon...',
                  Icons.branding_watermark_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Brand name is required'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _modelCtrl,
                decoration: _dec(
                  'Model *',
                  'e.g., XPS 15, LaserJet Pro...',
                  Icons.model_training_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Model is required'
                    : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _specCtrl,
                maxLines: 2,
                decoration: _dec(
                  'Specification / Configuration',
                  'e.g., i7, 16GB RAM, 512GB SSD...',
                  Icons.list_alt_rounded,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: _dec(
                  'Description',
                  'Additional details about this device...',
                  Icons.description_rounded,
                ),
              ),
              const SizedBox(height: 22),

              // ── Save button ──────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || !_isFormValid) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isEditing ? Icons.save_rounded : Icons.add_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : isEditing
                        ? 'Update Device'
                        : 'Save to Devices',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
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
