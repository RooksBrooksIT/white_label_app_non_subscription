import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/pdf_utils.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class AdminEngineerReports extends StatefulWidget {
  const AdminEngineerReports({super.key});

  @override
  _AdminEngineerReportsState createState() => _AdminEngineerReportsState();
}

class _AdminEngineerReportsState extends State<AdminEngineerReports>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 15;

  String? selectedEngineer;
  bool isDateFilterEnabled = false;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;
  bool isDateRangeMode = false;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _selectedLocationFilter = 'All';
  bool _showAdvancedFilters = false;
  bool _showAnalytics = true;
  int _currentPage = 1;
  String? _loadingPdfId;
  String? _downloadingPdfId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Map<String, Map<String, int>> engineerStatusCounts = {};
  Set<String> allStatuses = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Stream<List<String>> getEngineerUsernames() {
    return FirestoreService.instance
        .collection('EngineerLogin')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    (doc.data()['Username'] as String).trim().toLowerCase(),
              )
              .toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getEngineerProfiles() {
    return FirestoreService.instance
        .collection('EngineerLogin')
        .snapshots()
        .map((snapshot) {
          final profiles = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final username = (data['Username'] ?? '').toString().trim();
                return {
                  'id': doc.id,
                  'username': username.toLowerCase(),
                  'displayName': _capitalizeName(username),
                  'email': (data['Email'] ?? '').toString().trim(),
                  'phone': (data['Phone'] ?? '').toString().trim(),
                };
              })
              .where((p) => p['username'].toString().isNotEmpty)
              .toList();
          profiles.sort(
            (a, b) => a['displayName'].toString().compareTo(
              b['displayName'].toString(),
            ),
          );
          return profiles;
        });
  }

  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + (name.length > 1 ? name.substring(1) : '');
  }

  Map<String, dynamic>? _findEngineerProfile(
    List<Map<String, dynamic>> profiles,
    String assignedEmployee,
  ) {
    final key = assignedEmployee.trim().toLowerCase();
    for (final profile in profiles) {
      if (profile['username'] == key) return profile;
    }
    return null;
  }

  String _extractLocation(Map<String, dynamic> data) {
    for (final field in ['city', 'location', 'address', 'customerAddress']) {
      final value = data[field]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Unknown';
  }

  String _reportTitle(Map<String, dynamic> data) {
    final bookingId = data['bookingId']?.toString();
    final customer = data['customerName']?.toString();
    final device = data['deviceType']?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      return 'Ticket #$bookingId';
    }
    if (customer != null && customer.isNotEmpty) {
      return device != null && device.isNotEmpty
          ? '$customer · $device'
          : customer;
    }
    return 'Service Report';
  }

  List<QueryDocumentSnapshot> _filterReports(
    List<QueryDocumentSnapshot> docs,
    List<Map<String, dynamic>> engineerProfiles,
  ) {
    final query = searchQuery.trim().toLowerCase();

    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final assignedEmployee =
          data['assignedEmployee']?.toString().trim().toLowerCase() ?? '';
      if (assignedEmployee.isEmpty) return false;

      if (selectedEngineer != null &&
          assignedEmployee != selectedEngineer!.toLowerCase()) {
        return false;
      }

      if (_selectedStatusFilter != 'All') {
        final status = _normalizeStatusKey(
          data['adminStatus']?.toString() ?? '',
        );
        if (status != _selectedStatusFilter) return false;
      }

      if (_selectedLocationFilter != 'All') {
        if (_extractLocation(data) != _selectedLocationFilter) return false;
      }

      final timestamp = _parseTimestamp(data['timestamp']);
      if (!_matchesDateFilter(timestamp)) return false;

      if (query.isNotEmpty) {
        final profile = _findEngineerProfile(
          engineerProfiles,
          assignedEmployee,
        );
        final matchesEngineer =
            assignedEmployee.contains(query) ||
            (profile?['id']?.toString().toLowerCase().contains(query) ??
                false) ||
            (profile?['email']?.toString().toLowerCase().contains(query) ??
                false) ||
            (profile?['phone']?.toString().contains(query) ?? false) ||
            (profile?['displayName']?.toString().toLowerCase().contains(
                  query,
                ) ??
                false);
        final matchesTicket =
            (data['bookingId']?.toString().toLowerCase().contains(query) ??
                false) ||
            (data['customerName']?.toString().toLowerCase().contains(query) ??
                false) ||
            (data['id']?.toString().toLowerCase().contains(query) ?? false);
        if (!matchesEngineer && !matchesTicket) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final ta = _parseTimestamp((a.data() as Map)['timestamp']);
      final tb = _parseTimestamp((b.data() as Map)['timestamp']);
      return tb.compareTo(ta);
    });

    return filtered;
  }

  Set<String> _collectLocations(List<QueryDocumentSnapshot> docs) {
    return docs
        .map((doc) => _extractLocation(doc.data() as Map<String, dynamic>))
        .where((loc) => loc != 'Unknown')
        .toSet();
  }

  Future<void> _onRefresh() async {
    setState(() => _currentPage = 1);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _viewReportPdf(
    String engineerName,
    Map<String, dynamic> ticket,
    String rowId,
  ) async {
    setState(() => _loadingPdfId = rowId);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Opening PDF viewer...',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final pdf = await _generatePdf(engineerName, [ticket]);
      if (mounted) Navigator.of(context).pop();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Engineer_Report_${ticket['bookingId'] ?? DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showPdfError('Unable to open PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingPdfId = null);
    }
  }

  Future<void> _downloadReportPdf(
    String engineerName,
    Map<String, dynamic> ticket,
    String rowId,
  ) async {
    setState(() => _downloadingPdfId = rowId);
    try {
      final pdf = await _generatePdf(engineerName, [ticket]);
      final bookingId =
          ticket['bookingId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/Engineer_Report_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.green.shade700,
          content: const Text('PDF downloaded successfully'),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(file.path),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showPdfError('Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloadingPdfId = null);
    }
  }

  void _showPdfError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      selectedEngineer = null;
      searchQuery = '';
      _searchController.clear();
      _selectedStatusFilter = 'All';
      _selectedLocationFilter = 'All';
      isDateFilterEnabled = false;
      isDateRangeMode = false;
      selectedDate = null;
      fromDate = null;
      toDate = null;
      _currentPage = 1;
    });
  }

  Timestamp _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    if (v is String) {
      DateTime? dt = DateTime.tryParse(v);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    return Timestamp.now();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    final isDesktop = screenSize.width >= 1200;
    final adminDetailsStream = _buildAdminDetailsStream();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: isMobile ? 130 : 160,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.assignment_ind_rounded,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Engineer Reports',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isMobile ? 22 : 28,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Monitor performance & manage reports',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                20,
                isMobile ? 16 : 24,
                28,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ResponsiveWrapper(
                    maxWidth: 1200.0,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildSearchBar(isMobile),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ResponsiveWrapper(
                    maxWidth: 1200.0,
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: getEngineerProfiles(),
                    builder: (context, engineerSnapshot) {
                      final engineerProfiles = engineerSnapshot.data ?? [];
                      return StreamBuilder<QuerySnapshot>(
                        stream: adminDetailsStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingState(isMobile);
                          }
                          if (snapshot.hasError) {
                            return _buildErrorState(snapshot.error.toString());
                          }

                          engineerStatusCounts.clear();
                          allStatuses.clear();

                          final docs = snapshot.data?.docs ?? [];
                          for (final doc in docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final rawEngineerName = data['assignedEmployee']
                                ?.toString();
                            if (rawEngineerName != null) {
                              final engineerName = rawEngineerName
                                  .trim()
                                  .toLowerCase();
                              final normalizedStatus = _normalizeStatusKey(
                                data['adminStatus']?.toString() ?? '',
                              );
                              allStatuses.add(normalizedStatus);
                              engineerStatusCounts.putIfAbsent(
                                engineerName,
                                () => {},
                              );
                              engineerStatusCounts[engineerName]![normalizedStatus] =
                                  (engineerStatusCounts[engineerName]![normalizedStatus] ??
                                      0) +
                                  1;
                            }
                          }

                          final filteredReports = _filterReports(
                            docs,
                            engineerProfiles,
                          );
                          final locations = _collectLocations(docs).toList()
                            ..sort();
                          final statusOptions = allStatuses.toList()..sort();
                          final visibleCount =
                              (_currentPage * _pageSize) >
                                  filteredReports.length
                              ? filteredReports.length
                              : _currentPage * _pageSize;
                          final paginatedReports = filteredReports
                              .take(visibleCount)
                              .toList();
                          final hasMore = visibleCount < filteredReports.length;

                          if (filteredReports.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _buildFilterSection(
                                    isMobile,
                                    isTablet,
                                    isDesktop,
                                    statusOptions: statusOptions,
                                    locationOptions: locations,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildEmptyState(isMobile),
                              ],
                            );
                          }

                          final selectedCounts = selectedEngineer != null
                              ? engineerStatusCounts[selectedEngineer!
                                    .toLowerCase()]
                              : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildFilterSection(
                                  isMobile,
                                  isTablet,
                                  isDesktop,
                                  statusOptions: statusOptions,
                                  locationOptions: locations,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildReportsSummaryHeader(
                                filteredReports.length,
                                isMobile,
                                isDesktop,
                              ),
                              if (_showAnalytics &&
                                  selectedEngineer != null &&
                                  selectedCounts != null &&
                                  selectedCounts.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _buildDashboard(
                                  context,
                                  selectedCounts,
                                  filteredReports.length,
                                  docs,
                                  isMobile,
                                  isTablet,
                                  isDesktop,
                                ),
                              ],
                              const SizedBox(height: 28),
                              _buildReportsListHeader(
                                filteredReports.length,
                                isMobile,
                                docs,
                              ),
                              const SizedBox(height: 16),
                              if (isDesktop)
                                _buildReportsTable(
                                  paginatedReports,
                                  engineerProfiles,
                                )
                              else
                                ...paginatedReports.map(
                                  (doc) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildReportCard(
                                      doc,
                                      engineerProfiles,
                                      isMobile,
                                    ),
                                  ),
                                ),
                              if (hasMore)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          setState(() => _currentPage += 1),
                                      icon: const Icon(Icons.expand_more),
                                      label: Text(
                                        'Load more (${filteredReports.length - visibleCount} remaining)',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Theme.of(
                                          context,
                                        ).primaryColor,
                                        side: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.3),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText:
              'Search by engineer name, ID, mobile, email, or booking ID...',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: isMobile ? 13 : 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      searchQuery = '';
                      _currentPage = 1;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isMobile ? 16 : 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop, {
    List<String> statusOptions = const [],
    List<String> locationOptions = const [],
  }) {
    final isDropdownDisabled =
        isDateFilterEnabled &&
        ((!isDateRangeMode && selectedDate == null) ||
            (isDateRangeMode && (fromDate == null || toDate == null)));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.filter_alt_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Smart Filters',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset all'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isDesktop)
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                SizedBox(width: 280, child: _buildDateFilterControls(isMobile)),
                SizedBox(
                  width: 260,
                  child: _buildEngineerSelector(isDropdownDisabled, isMobile),
                ),
                SizedBox(
                  width: 200,
                  child: _buildStatusFilter(statusOptions, isMobile),
                ),
                if (locationOptions.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: _buildLocationFilter(locationOptions, isMobile),
                  ),
              ],
            )
          else ...[
            _buildDateFilterControls(isMobile),
            const SizedBox(height: 16),
            _buildEngineerSelector(isDropdownDisabled, isMobile),
            if (_showAdvancedFilters) ...[
              const SizedBox(height: 16),
              _buildStatusFilter(statusOptions, isMobile),
              if (locationOptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildLocationFilter(locationOptions, isMobile),
              ],
            ],
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!isDesktop)
                ActionChip(
                  avatar: Icon(
                    _showAdvancedFilters
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  label: Text(
                    _showAdvancedFilters
                        ? 'Hide advanced filters'
                        : 'More filters',
                  ),
                  onPressed: () => setState(
                    () => _showAdvancedFilters = !_showAdvancedFilters,
                  ),
                  backgroundColor: Colors.grey.shade100,
                ),
              ActionChip(
                avatar: Icon(
                  _showAnalytics ? Icons.visibility_off : Icons.insights,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                label: Text(
                  _showAnalytics ? 'Hide analytics' : 'Show analytics',
                ),
                onPressed: () =>
                    setState(() => _showAnalytics = !_showAnalytics),
                backgroundColor: Colors.grey.shade100,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(List<String> statusOptions, bool isMobile) {
    final options = ['All', ...statusOptions.toList()..sort()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Colors.white,
              value: options.contains(_selectedStatusFilter)
                  ? _selectedStatusFilter
                  : 'All',
              isExpanded: true,
              items: options
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(
                        status,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedStatusFilter = value ?? 'All';
                _currentPage = 1;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFilter(List<String> locationOptions, bool isMobile) {
    final options = ['All', ...locationOptions];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Colors.white,
              value: options.contains(_selectedLocationFilter)
                  ? _selectedLocationFilter
                  : 'All',
              isExpanded: true,
              items: options
                  .map(
                    (location) => DropdownMenuItem(
                      value: location,
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedLocationFilter = value ?? 'All';
                _currentPage = 1;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterControls(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: isDateFilterEnabled
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade500,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Date filter',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Switch.adaptive(
              value: isDateFilterEnabled,
              onChanged: (bool? newValue) {
                setState(() {
                  isDateFilterEnabled = newValue ?? false;
                  if (!isDateFilterEnabled) {
                    selectedDate = null;
                    fromDate = null;
                    toDate = null;
                  }
                  _currentPage = 1;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
        if (isDateFilterEnabled) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                isDateRangeMode ? 'Date Range' : 'Single Date',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: isDateRangeMode,
                onChanged: (bool? newValue) {
                  setState(() {
                    isDateRangeMode = newValue ?? false;
                    selectedDate = null;
                    fromDate = null;
                    toDate = null;
                    _currentPage = 1;
                  });
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isDateRangeMode)
            _buildDatePicker('Select date', selectedDate, (pickedDate) {
              setState(() {
                selectedDate = pickedDate;
                _currentPage = 1;
              });
            }, isMobile)
          else
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker('From', fromDate, (pickedDate) {
                    setState(() {
                      fromDate = pickedDate;
                      if (toDate != null && toDate!.isBefore(pickedDate)) {
                        toDate = null;
                      }
                      _currentPage = 1;
                    });
                  }, isMobile),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDatePicker(
                    'To',
                    toDate,
                    (pickedDate) {
                      if (fromDate != null && pickedDate.isBefore(fromDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid date range'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        toDate = pickedDate;
                        _currentPage = 1;
                      });
                    },
                    isMobile,
                    minDate: fromDate,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildEngineerSelector(bool isDropdownDisabled, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engineer',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: getEngineerProfiles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }

            final engineers = snapshot.data ?? [];
            final items = [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Engineers'),
              ),
              ...engineers.map(
                (engineer) => DropdownMenuItem<String>(
                  value: engineer['username'] as String,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        engineer['displayName'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'ID: ${engineer['id']} · ${engineer['phone']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  dropdownColor: Colors.white,
                  value: selectedEngineer?.toLowerCase(),
                  hint: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: isDropdownDisabled
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isDropdownDisabled
                              ? 'Select date range first'
                              : 'All engineers',
                          style: TextStyle(
                            color: isDropdownDisabled
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  items: items,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDropdownDisabled
                        ? Colors.grey.shade400
                        : Theme.of(context).primaryColor,
                  ),
                  onChanged: isDropdownDisabled
                      ? null
                      : (newValue) {
                          setState(() {
                            selectedEngineer = newValue;
                            _currentPage = 1;
                          });
                        },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? currentDate,
    Function(DateTime) onDateSelected,
    bool isMobile, {
    DateTime? minDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: currentDate ?? DateTime.now(),
              firstDate: minDate ?? DateTime(2000),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Theme.of(context).primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black87,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null) {
              onDateSelected(pickedDate);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentDate == null
                        ? 'Select date'
                        : DateFormat('dd MMM yyyy').format(currentDate),
                    style: TextStyle(
                      color: currentDate == null
                          ? Colors.grey.shade500
                          : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsSummaryHeader(
    int totalReports,
    bool isMobile,
    bool isDesktop,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.06),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.summarize_rounded,
              color: Theme.of(context).primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalReports report${totalReports == 1 ? '' : 's'} found',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing ${(_currentPage * _pageSize).clamp(0, totalReports)} of $totalReports',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsListHeader(
    int totalReports,
    bool isMobile,
    List<QueryDocumentSnapshot> docs,
  ) {
    return Row(
      children: [
        Icon(
          Icons.receipt_long_rounded,
          color: Theme.of(context).primaryColor,
          size: 26,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Ticket Reports',
            style: TextStyle(
              color: Colors.black87,
              fontSize: isMobile ? 20 : 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (selectedEngineer != null) _buildExportButton(docs, isMobile),
      ],
    );
  }

  Widget _buildReportsTable(
    List<QueryDocumentSnapshot> reports,
    List<Map<String, dynamic>> engineerProfiles,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).primaryColor.withValues(alpha: 0.05),
            ),
            columnSpacing: 24,
            horizontalMargin: 16,
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87,
            ),
            dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
            columns: const [
              DataColumn(label: Text('Engineer')),
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Report Title')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('PDF')),
              DataColumn(label: Text('Actions')),
            ],
            rows: reports.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildReportDataRow(doc.id, data, engineerProfiles);
            }).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildReportDataRow(
    String rowId,
    Map<String, dynamic> data,
    List<Map<String, dynamic>> engineerProfiles,
  ) {
    final assignedEmployee =
        data['assignedEmployee']?.toString().trim() ?? 'Unknown';
    final profile = _findEngineerProfile(engineerProfiles, assignedEmployee);
    final engineerName =
        profile?['displayName']?.toString() ??
        _capitalizeName(assignedEmployee);
    final engineerId = profile?['id']?.toString() ?? '—';
    final status = _normalizeStatusKey(data['adminStatus']?.toString() ?? '');
    final statusColor = _getStatusColor(status);
    final timestamp = _parseTimestamp(data['timestamp']);
    final formattedDate = DateFormat(
      'dd MMM yyyy · hh:mm a',
    ).format(timestamp.toDate());
    final hasPdf = assignedEmployee.isNotEmpty;
    final isViewLoading = _loadingPdfId == rowId;
    final isDownloadLoading = _downloadingPdfId == rowId;

    return DataRow(
      cells: [
        DataCell(
          Text(
            engineerName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(Text(engineerId)),
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              _reportTitle(data),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(formattedDate)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        DataCell(
          Icon(
            hasPdf ? Icons.picture_as_pdf_rounded : Icons.error_outline,
            color: hasPdf ? Colors.green.shade600 : Colors.orange.shade700,
            size: 20,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPdfActionButton(
                label: 'View',
                icon: Icons.visibility_rounded,
                isLoading: isViewLoading,
                enabled: hasPdf && !isViewLoading && !isDownloadLoading,
                onPressed: () => _viewReportPdf(assignedEmployee, data, rowId),
              ),
              const SizedBox(width: 10),
              _buildPdfActionButton(
                label: 'Download',
                icon: Icons.download_rounded,
                isLoading: isDownloadLoading,
                enabled: hasPdf && !isViewLoading && !isDownloadLoading,
                onPressed: () =>
                    _downloadReportPdf(assignedEmployee, data, rowId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(
    QueryDocumentSnapshot doc,
    List<Map<String, dynamic>> engineerProfiles,
    bool isMobile,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final assignedEmployee =
        data['assignedEmployee']?.toString().trim() ?? 'Unknown';
    final profile = _findEngineerProfile(engineerProfiles, assignedEmployee);
    final engineerName =
        profile?['displayName']?.toString() ??
        _capitalizeName(assignedEmployee);
    final engineerId = profile?['id']?.toString() ?? '—';
    final email = profile?['email']?.toString() ?? '';
    final phone = profile?['phone']?.toString() ?? '';
    final status = _normalizeStatusKey(data['adminStatus']?.toString() ?? '');
    final statusColor = _getStatusColor(status);
    final timestamp = _parseTimestamp(data['timestamp']);
    final formattedDate = DateFormat(
      'dd MMM yyyy · hh:mm a',
    ).format(timestamp.toDate());
    final hasPdf = assignedEmployee.isNotEmpty;
    final isViewLoading = _loadingPdfId == doc.id;
    final isDownloadLoading = _downloadingPdfId == doc.id;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
                child: Text(
                  engineerName.isNotEmpty ? engineerName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      engineerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $engineerId',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (phone.isNotEmpty || email.isNotEmpty)
                      Text(
                        [phone, email].where((v) => v.isNotEmpty).join(' · '),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _reportTitle(data),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Spacer(),
              Icon(
                hasPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.warning_amber_rounded,
                size: 16,
                color: hasPdf ? Colors.green.shade600 : Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                hasPdf ? 'PDF Ready' : 'No PDF',
                style: TextStyle(
                  color: hasPdf
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildPdfActionButton(
                  label: 'View PDF',
                  icon: Icons.visibility_rounded,
                  isLoading: isViewLoading,
                  expanded: true,
                  enabled: hasPdf && !isViewLoading && !isDownloadLoading,
                  onPressed: () =>
                      _viewReportPdf(assignedEmployee, data, doc.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPdfActionButton(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  isLoading: isDownloadLoading,
                  expanded: true,
                  enabled: hasPdf && !isViewLoading && !isDownloadLoading,
                  onPressed: () =>
                      _downloadReportPdf(assignedEmployee, data, doc.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required bool enabled,
    required VoidCallback onPressed,
    bool expanded = false,
  }) {
    final child = OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).primaryColor,
        side: BorderSide(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }

  Widget _buildDashboard(
    BuildContext context,
    Map<String, int> selectedCounts,
    int totalTickets,
    List<QueryDocumentSnapshot> docs,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKPICards(totalTickets, docs, isMobile),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Status Breakdown',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: isMobile ? 20 : 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (!isMobile) _buildExportButton(docs, isMobile),
          ],
        ),
        const SizedBox(height: 24),
        _buildStatusGrid(selectedCounts, isMobile, isTablet),
        const SizedBox(height: 24),
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildExportButton(docs, isMobile),
          ),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                selectedEngineer = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Clear selection'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildKPICards(
    int totalTickets,
    List<QueryDocumentSnapshot> docs,
    bool isMobile,
  ) {
    final tickets = docs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final assignedEmployee = data['assignedEmployee']
              ?.toString()
              .trim()
              .toLowerCase();
          final timestamp = _parseTimestamp(data['timestamp']);
          return assignedEmployee == selectedEngineer!.toLowerCase() &&
              _matchesDateFilter(timestamp);
        })
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    double totalAmount = 0;
    int completedTickets = 0;

    for (final ticket in tickets) {
      final amount = double.tryParse(ticket['amount']?.toString() ?? '0') ?? 0;
      totalAmount += amount;

      final status = _normalizeStatusKey(
        ticket['adminStatus']?.toString() ?? 'Unknown',
      );
      if (status.toLowerCase().contains('complete')) {
        completedTickets++;
      }
    }

    final completionRate = tickets.isNotEmpty
        ? (completedTickets / tickets.length * 100).toStringAsFixed(1)
        : '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 2 : 4;
        final availableWidth = constraints.maxWidth;
        final itemWidth = (availableWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
        final childAspectRatio = itemWidth / 150.0;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
        _buildKPICard(
          'Total Tasks',
          totalTickets.toString(),
          Icons.assignment_rounded,
          Colors.blue.shade600,
        ),
        _buildKPICard(
          'Completed',
          completedTickets.toString(),
          Icons.check_circle_rounded,
          Colors.green.shade600,
        ),
        _buildKPICard(
          'Completion Rate',
          '$completionRate%',
          Icons.trending_up_rounded,
          Colors.orange.shade600,
        ),
        _buildKPICard(
          'Total Revenue',
          '₹${totalAmount.toStringAsFixed(0)}',
          Icons.currency_rupee_rounded,
          Colors.purple.shade600,
        ),
      ],
    );
    },
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(
    Map<String, int> selectedCounts,
    bool isMobile,
    bool isTablet,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);
        final availableWidth = constraints.maxWidth;
        final itemWidth = (availableWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
        final childAspectRatio = itemWidth / 165.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: selectedCounts.length,
          itemBuilder: (context, index) {
        final entry = selectedCounts.entries.elementAt(index);
        final status = entry.key;
        final count = entry.value;
        final color = _getStatusColor(status);
        final icon = _getStatusIcon(status);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
    },
    );
  }

  Widget _buildExportButton(List<QueryDocumentSnapshot> docs, bool isMobile) {
    return ElevatedButton.icon(
      onPressed: () async {
        final tickets = docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final assignedEmployee = data['assignedEmployee']
                  ?.toString()
                  .trim()
                  .toLowerCase();
              final timestamp = _parseTimestamp(data['timestamp']);
              return assignedEmployee == selectedEngineer!.toLowerCase() &&
                  _matchesDateFilter(timestamp);
            })
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Generating PDF Report...',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

        try {
          final pdf = await _generatePdf(selectedEngineer!, tickets);
          if (mounted) {
            Navigator.of(context).pop();
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdf.save(),
              name:
                  'Engineer_Report_${selectedEngineer}_${DateTime.now().millisecondsSinceEpoch}',
            );
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating PDF: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
      icon: Icon(Icons.picture_as_pdf_rounded, size: isMobile ? 20 : 22),
      label: Text(isMobile ? 'PDF' : 'Export PDF Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 22 : 28,
          vertical: isMobile ? 14 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 2,
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading performance data...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isMobile ? 15 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            'Error loading data',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 56,
              color: Colors.orange.shade300,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'No Reports Found',
            style: TextStyle(
              fontSize: isMobile ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Try adjusting your search, filters, or date range',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isMobile ? 15 : 16,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Clear all filters'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildAdminDetailsStream() {
    if (isDateFilterEnabled) {
      if (!isDateRangeMode && selectedDate != null) {
        final startOfDay = Timestamp.fromDate(
          DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day),
        );
        final endOfDay = Timestamp.fromDate(
          DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
          ).add(const Duration(days: 1)),
        );
        return FirestoreService.instance
            .collection('Admin_details')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThan: endOfDay)
            .snapshots();
      } else if (isDateRangeMode && fromDate != null && toDate != null) {
        final startOfDay = Timestamp.fromDate(
          DateTime(fromDate!.year, fromDate!.month, fromDate!.day),
        );
        final endOfDay = Timestamp.fromDate(
          DateTime(
            toDate!.year,
            toDate!.month,
            toDate!.day,
          ).add(const Duration(days: 1)),
        );
        return FirestoreService.instance
            .collection('Admin_details')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThan: endOfDay)
            .snapshots();
      }
    }
    return FirestoreService.instance.collection('Admin_details').snapshots();
  }

  bool _matchesDateFilter(Timestamp? timestamp) {
    if (!isDateFilterEnabled) return true;
    if (timestamp == null) return false;

    final dt = timestamp.toDate();

    if (!isDateRangeMode && selectedDate != null) {
      return dt.year == selectedDate!.year &&
          dt.month == selectedDate!.month &&
          dt.day == selectedDate!.day;
    } else if (isDateRangeMode && fromDate != null && toDate != null) {
      final date = DateTime(dt.year, dt.month, dt.day);
      final from = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final to = DateTime(toDate!.year, toDate!.month, toDate!.day);

      return (date.isAfter(from) || date.isAtSameMomentAs(from)) &&
          (date.isBefore(to) || date.isAtSameMomentAs(to));
    }

    return false;
  }

  String _normalizeStatusKey(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case "complete":
      case "completed":
      case "closed":
      case "close":
        return "Completed";
      case "on progress":
        return "On Progress";
      case "pending for spares":
      case "pending for spares (pfs)":
        return "Pending Spares";
      case "pending for approval":
      case "pending for approval (pfa)":
        return "Pending Approval";
      case "under the observation":
      case "on - hold":
      case "on hold":
        return "On Hold";
      default:
        return status
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
    }
  }

  // PDF generation unchanged (preserved functionality)
  Future<pw.Document> _generatePdf(
    String engineerName,
    List<Map<String, dynamic>> tickets,
  ) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    final logoUrl = ThemeService.instance.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      logoImage = await PdfUtils.fetchNetworkImage(logoUrl);
    }

    final robotoRegular = await PdfGoogleFonts.robotoRegular();
    final robotoBold = await PdfGoogleFonts.robotoBold();

    String formatTimestamp(Timestamp? timestamp) {
      if (timestamp == null) return 'N/A';
      final dt = timestamp.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    String truncateText(String text, {int maxLength = 30}) {
      if (text.length <= maxLength) return text;
      return '${text.substring(0, maxLength)}...';
    }

    String getReportPeriod() {
      if (!isDateFilterEnabled) return 'All Time';
      if (!isDateRangeMode && selectedDate != null) {
        return selectedDate!.toLocal().toString().split(' ')[0];
      }
      if (isDateRangeMode && fromDate != null && toDate != null) {
        return '${fromDate!.toLocal().toString().split(' ')[0]} to ${toDate!.toLocal().toString().split(' ')[0]}';
      }
      return 'All Time';
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: robotoRegular,
          bold: robotoBold,
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 60,
                    height: 60,
                    margin: const pw.EdgeInsets.only(right: 20),
                    child: pw.Image(logoImage),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ENGINEER PERFORMANCE REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated on ${DateTime.now().toLocal().toString().split(' ')[0]}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue800,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    'CONFIDENTIAL',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Service Management System',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Engineer Details',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Name: ',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            engineerName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Report Period: ',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            getReportPeriod(),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Total Tickets: ',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            tickets.length.toString(),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(30),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        engineerName.substring(0, 1).toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 20,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Detailed Ticket Analysis',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    'Total: ${tickets.length} tickets',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            if (tickets.isEmpty)
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(40),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('📊', style: pw.TextStyle(fontSize: 24)),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'No tickets found for the selected criteria',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              pw.Table.fromTextArray(
                border: null,
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    topRight: pw.Radius.circular(4),
                  ),
                ),
                rowDecoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.0),
                  2: const pw.FlexColumnWidth(0.8),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(0.7),
                  5: const pw.FlexColumnWidth(1.0),
                  6: const pw.FlexColumnWidth(1.0),
                  7: const pw.FlexColumnWidth(0.8),
                },
                headers: [
                  'Booking ID',
                  'Device Type',
                  'Brand',
                  'Issue Description',
                  'Amount',
                  'Eng Status',
                  'Admin Status',
                  'Date',
                ],
                data: tickets.map((ticket) {
                  return [
                    ticket['bookingId']?.toString() ?? 'N/A',
                    ticket['deviceType']?.toString() ?? 'N/A',
                    ticket['deviceBrand']?.toString() ?? 'N/A',
                    truncateText(
                      ticket['message']?.toString() ?? 'No description',
                      maxLength: 35,
                    ),
                    '₹${ticket['amount']?.toString() ?? '0'}',
                    _getStatusAbbr(
                      ticket['engineerStatus']?.toString() ?? 'N/A',
                    ),
                    _getStatusAbbr(ticket['adminStatus']?.toString() ?? 'N/A'),
                    formatTimestamp(ticket['timestamp'] as Timestamp?),
                  ];
                }).toList(),
              ),
          ];
        },
      ),
    );

    return pdf;
  }

  String _getStatusAbbr(String status) {
    final lower = status.toLowerCase();
    if (lower.contains("complete")) return "COMP";
    if (lower.contains("progress")) return "PROG";
    if (lower.contains("spares")) return "PFS";
    if (lower.contains("approval")) return "PFA";
    if (lower.contains("hold")) return "HOLD";
    if (status.length <= 8) return status;
    return status.substring(0, 8);
  }

  IconData _getStatusIcon(String status) {
    final lower = status.toLowerCase();
    if (lower.contains("complete")) return Icons.check_circle_outline;
    if (lower.contains("progress")) return Icons.pending_outlined;
    if (lower.contains("spares") || lower.contains("spa")) {
      return Icons.build_outlined;
    }
    if (lower.contains("approval") || lower.contains("spc")) {
      return Icons.gavel_outlined;
    }
    if (lower.contains("hold")) return Icons.pause_circle_outline;
    return Icons.report_problem_outlined;
  }

  Color _getStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains("complete") || lower.contains("assign")) {
      return const Color(0xFF4CAF50);
    }
    if (lower.contains("progress")) return const Color(0xFF2196F3);
    if (lower.contains("spares") || lower.contains("spa")) {
      return const Color(0xFFFF9800);
    }
    if (lower.contains("approval") || lower.contains("spc")) {
      return const Color(0xFFF44336);
    }
    if (lower.contains("hold")) return const Color(0xFF9E9E9E);
    return Colors.blueGrey;
  }
}
