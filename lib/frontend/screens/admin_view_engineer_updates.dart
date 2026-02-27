import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class EngineerUpdates extends StatefulWidget {
  const EngineerUpdates({super.key});

  @override
  State<EngineerUpdates> createState() => _EngineerUpdatesState();
}

class _EngineerUpdatesState extends State<EngineerUpdates> {
  // Filter state with proper typing
  Map<String, dynamic> activeFilters = {};
  List<QueryDocumentSnapshot> filteredDocs = [];
  bool filtersApplied = false;
  bool isSearchExpanded = false;

  // Data for filters
  List<String> engineerUsernames = ['All Engineers'];
  List<String> statusOptions = [
    'All Statuses',
    'Assigned',
    'Pending',
    'In Progress',
    'Pending for Approval',
    'Pending for Spares',
    'Observation',
    'Completed',
    'Canceled',
    'Unrepairable',
  ];
  bool isLoadingEngineers = true;
  String selectedEngineer = 'All Engineers';
  String selectedStatus = 'All Statuses';
  TextEditingController searchController = TextEditingController();
  TextEditingController bookingIdController = TextEditingController();
  TextEditingController customerIdController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // Design tokens (dynamic via ThemeService)
  late Color primaryBlue;
  late Color accentBlue;
  late Color surfaceColor;
  late Color cardColor;
  late Color headerTextColor;
  late Color bodyTextColor;

  @override
  void initState() {
    super.initState();
    _fetchEngineerUsernames();
  }

  Future<void> _fetchEngineerUsernames() async {
    try {
      QuerySnapshot querySnapshot = await FirestoreService.instance
          .collection('EngineerLogin')
          .get();

      List<String> usernames = ['All Engineers'];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['Username'] != null) {
          usernames.add(data['Username'].toString());
        }
      }

      setState(() {
        engineerUsernames = usernames;
        isLoadingEngineers = false;
      });
    } catch (e) {
      print('Error fetching engineer usernames: $e');
      setState(() {
        isLoadingEngineers = false;
      });
    }
  }

  // Helper method for safe string conversion
  String _safeString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase().trim();

    if (statusLower == 'assigned' ||
        statusLower == 'completed' ||
        statusLower == 'complete' ||
        statusLower == 'delivered') {
      return Colors.green;
    }

    if (statusLower == 'not assigned' || statusLower == 'not assinged') {
      return Colors.red;
    }

    if (statusLower.contains('approval')) {
      return Colors.purple;
    }

    if (statusLower.contains('spare')) {
      return Colors.amber;
    }

    if (statusLower.contains('observation')) {
      return Colors.cyan;
    }

    if (statusLower == 'canceled' ||
        statusLower == 'cancelled' ||
        statusLower.contains('cancel')) {
      return Colors.grey;
    }

    if (statusLower == 'appointment') {
      return Colors.pink;
    }

    if (statusLower == 'open' ||
        statusLower == 'pending' ||
        statusLower.contains('progress')) {
      return Colors.orange;
    }

    if (statusLower == 'closed') {
      return Colors.blue;
    }

    return Colors.blueGrey;
  }

  void _applyFilters(List<QueryDocumentSnapshot> docs) {
    setState(() {
      filteredDocs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Global Search Filter (Search Bar)
        if (searchController.text.isNotEmpty) {
          final searchTerm = searchController.text.toLowerCase();
          final bookingId = _safeString(data['bookingId']).toLowerCase();
          final customerName = _safeString(data['customerName']).toLowerCase();
          final customerId = _safeString(data['id']).toLowerCase();

          if (!bookingId.contains(searchTerm) &&
              !customerName.contains(searchTerm) &&
              !customerId.contains(searchTerm)) {
            return false;
          }
        }

        // Booking ID filter (Detailed Filter)
        if (activeFilters.containsKey('bookingId')) {
          final bookingId = _safeString(data['bookingId']).toLowerCase();
          final searchTerm = activeFilters['bookingId']
              .toString()
              .toLowerCase();
          if (!bookingId.contains(searchTerm)) {
            return false;
          }
        }

        // Customer ID filter (Detailed Filter)
        if (activeFilters.containsKey('customerId')) {
          final customerId = _safeString(data['id']).toLowerCase();
          final searchTerm = activeFilters['customerId']
              .toString()
              .toLowerCase();
          if (!customerId.contains(searchTerm)) {
            return false;
          }
        }

        // Date Range filter
        if (startDate != null) {
          final rawTimestamp = data['timestamp'];
          DateTime? date;

          if (rawTimestamp is Timestamp) {
            date = rawTimestamp.toDate();
          } else if (rawTimestamp is String) {
            date = DateTime.tryParse(rawTimestamp);
          }

          if (date != null) {
            final filterEndDate = endDate ?? startDate!;
            final startOfDay = DateTime(
              startDate!.year,
              startDate!.month,
              startDate!.day,
            );
            final endOfDay = DateTime(
              filterEndDate.year,
              filterEndDate.month,
              filterEndDate.day,
              23,
              59,
              59,
            );

            if (date.isBefore(startOfDay) || date.isAfter(endOfDay)) {
              return false;
            }
          } else {
            return false;
          }
        }

        // Engineer filter
        if (selectedEngineer != 'All Engineers') {
          final assignedEmployee = _safeString(data['assignedEmployee']);
          if (assignedEmployee != selectedEngineer) {
            return false;
          }
        }

        // Status filter
        if (selectedStatus != 'All Statuses') {
          final engineerStatus = _safeString(
            data['engineerStatus'],
          ).toLowerCase();
          final adminStatus = _safeString(data['adminStatus']).toLowerCase();

          bool statusMatches = false;

          switch (selectedStatus) {
            case 'Pending':
              statusMatches =
                  engineerStatus == 'pending' ||
                  engineerStatus == 'open' ||
                  adminStatus == 'pending' ||
                  adminStatus == 'open';
              break;
            case 'Assigned':
              statusMatches =
                  engineerStatus == 'assigned' || adminStatus == 'assigned';
              break;
            case 'In Progress':
              statusMatches =
                  engineerStatus.contains('progress') ||
                  engineerStatus == 'in progress';
              break;
            case 'Pending for Approval':
              statusMatches =
                  engineerStatus.contains('approval') ||
                  engineerStatus == 'pfa';
              break;
            case 'Pending for Spares':
              statusMatches =
                  engineerStatus.contains('spare') || engineerStatus == 'pfs';
              break;
            case 'Observation':
              statusMatches = engineerStatus.contains('observation');
              break;
            case 'Completed':
              statusMatches =
                  adminStatus == 'completed' ||
                  adminStatus == 'complete' ||
                  adminStatus == 'delivered' ||
                  adminStatus == 'closed' ||
                  engineerStatus == 'completed' ||
                  engineerStatus == 'complete';
              break;
            case 'Canceled':
              statusMatches =
                  adminStatus == 'canceled' ||
                  adminStatus == 'cancelled' ||
                  engineerStatus == 'canceled' ||
                  engineerStatus == 'cancelled';
              break;
            case 'Unrepairable':
              statusMatches =
                  engineerStatus == 'unrepairable' ||
                  adminStatus == 'unrepairable';
              break;
            default:
              statusMatches =
                  engineerStatus == selectedStatus.toLowerCase() ||
                  adminStatus == selectedStatus.toLowerCase();
          }

          if (!statusMatches) {
            return false;
          }
        }

        return true;
      }).toList();

      // Update active filters state
      Map<String, dynamic> newFilters = {};
      if (searchController.text.isNotEmpty) {
        newFilters['query'] = searchController.text;
      }
      if (bookingIdController.text.isNotEmpty) {
        newFilters['bookingId'] = bookingIdController.text;
      }
      if (customerIdController.text.isNotEmpty) {
        newFilters['customerId'] = customerIdController.text;
      }
      if (selectedEngineer != 'All Engineers') {
        newFilters['engineer'] = selectedEngineer;
      }
      if (selectedStatus != 'All Statuses') {
        newFilters['status'] = selectedStatus;
      }
      if (startDate != null) {
        newFilters['dateRange'] = {'start': startDate, 'end': endDate};
      }
      activeFilters = newFilters;
      filtersApplied = activeFilters.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      activeFilters.clear();
      filteredDocs.clear();
      filtersApplied = false;
      searchController.clear();
      bookingIdController.clear();
      customerIdController.clear();
      selectedEngineer = 'All Engineers';
      selectedStatus = 'All Statuses';
      startDate = null;
      endDate = null;
    });
  }

  void _removeFilter(String key) {
    setState(() {
      activeFilters.remove(key);
      if (key == 'query') {
        searchController.clear();
      } else if (key == 'bookingId') {
        bookingIdController.clear();
      } else if (key == 'customerId') {
        customerIdController.clear();
      } else if (key == 'engineer') {
        selectedEngineer = 'All Engineers';
      } else if (key == 'status') {
        selectedStatus = 'All Statuses';
      } else if (key == 'dateRange') {
        startDate = null;
        endDate = null;
      }
      if (activeFilters.isEmpty) {
        filtersApplied = false;
        filteredDocs.clear();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    bookingIdController.dispose();
    customerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Refresh colors from ThemeService
    primaryBlue = ThemeService.instance.primaryColor;
    accentBlue = ThemeService.instance.secondaryColor;
    surfaceColor = ThemeService.instance.backgroundColor;
    cardColor = Colors.white;
    headerTextColor = const Color(0xFF1E293B);
    bodyTextColor = const Color(0xFF475569);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        toolbarHeight: isSearchExpanded ? 110 : 70,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: isSearchExpanded
            ? _buildSearchField()
            : const Text(
                'Engineer Updates',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
        centerTitle: false,
        actions: [
          if (!isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              onPressed: () => setState(() => isSearchExpanded = true),
            ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white),
                if (activeFilters.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _buildFilterBottomSheet(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: isSearchExpanded
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
              ),
      ),
      body: Column(
        children: [
          _buildEnhancedFilterSummary(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.instance
                  .collection('Admin_details')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                final allUpdateDocs = snapshot.data?.docs ?? [];

                // Pre-filter: Only show tickets that have been actively updated by an engineer
                final updateDocs = allUpdateDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // A ticket is considered "updated" if it has been actively modified by an engineer.
                  // We exclude initial statuses: 'Assigned', 'Not Assigned', 'Ticket Created'.
                  final engineerStatus =
                      (data['engineerStatus']?.toString() ?? '')
                          .trim()
                          .toLowerCase();

                  final isInitialStatus =
                      engineerStatus == 'assigned' ||
                      engineerStatus == 'not assigned' ||
                      engineerStatus == 'ticket created' ||
                      engineerStatus.isEmpty;

                  final hasDescription =
                      (data['description']?.toString() ?? '').isNotEmpty;
                  final hasLastUpdated = data['lastUpdated'] != null;
                  final hasAmount = (data['amount'] as num? ?? 0) > 0;

                  return !isInitialStatus ||
                      hasDescription ||
                      hasLastUpdated ||
                      hasAmount;
                }).toList();

                // Apply search and filters in real-time
                final docsToShow =
                    filteredDocs.isNotEmpty ||
                        filtersApplied ||
                        searchController.text.isNotEmpty
                    ? (filteredDocs.isEmpty && searchController.text.isNotEmpty
                          ? updateDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final searchTerm = searchController.text
                                  .toLowerCase();
                              final bookingId = _safeString(
                                data['bookingId'],
                              ).toLowerCase();
                              final customerName = _safeString(
                                data['customerName'],
                              ).toLowerCase();
                              return bookingId.contains(searchTerm) ||
                                  customerName.contains(searchTerm);
                            }).toList()
                          : filteredDocs.where((doc) {
                              // Ensure filtered segments also respect the active update rule
                              final data = doc.data() as Map<String, dynamic>;
                              final engineerStatus =
                                  (data['engineerStatus']?.toString() ?? '')
                                      .trim()
                                      .toLowerCase();

                              final isInitialStatus =
                                  engineerStatus == 'assigned' ||
                                  engineerStatus == 'not assigned' ||
                                  engineerStatus == 'ticket created' ||
                                  engineerStatus.isEmpty;

                              final hasDescription =
                                  (data['description']?.toString() ?? '')
                                      .isNotEmpty;
                              final hasLastUpdated =
                                  data['lastUpdated'] != null;
                              final hasAmount =
                                  (data['amount'] as num? ?? 0) > 0;
                              return !isInitialStatus ||
                                  hasDescription ||
                                  hasLastUpdated ||
                                  hasAmount;
                            }).toList())
                    : updateDocs;

                final reversedDocs = docsToShow.reversed.toList();

                if (reversedDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  itemCount: reversedDocs.length,
                  itemBuilder: (context, index) {
                    return EngineerUpdateCard(reversedDocs[index], index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        autofocus: true,
        style: TextStyle(color: headerTextColor, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search Booking ID or Customer...',
          hintStyle: TextStyle(
            color: bodyTextColor.withOpacity(0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: primaryBlue, size: 20),
          suffixIcon: IconButton(
            icon: Icon(Icons.close_rounded, color: bodyTextColor, size: 20),
            onPressed: () {
              setState(() {
                searchController.clear();
                isSearchExpanded = false;
                _applyFilters(
                  filteredDocs,
                ); // Re-apply current filters without search
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          FirestoreService.instance
              .collection('Admin_details')
              .get()
              .then((snapshot) => _applyFilters(snapshot.docs));
        },
      ),
    );
  }

  Widget _buildEnhancedFilterSummary() {
    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Applied Filters',
                style: TextStyle(
                  color: headerTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearAllFilters,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: activeFilters.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildEnhancedFilterChip(entry.key, entry.value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterChip(String key, dynamic value) {
    String label = '';
    IconData icon = Icons.filter_alt;

    switch (key) {
      case 'query':
        label = 'Search: $value';
        icon = Icons.search_rounded;
        break;
      case 'engineer':
        label = 'Eng: $value';
        icon = Icons.engineering_rounded;
        break;
      case 'status':
        label = value;
        icon = Icons.info_outline_rounded;
        break;
      case 'bookingId':
        label = 'ID: $value';
        icon = Icons.tag_rounded;
        break;
      case 'customerId':
        label = 'Cust: $value';
        icon = Icons.person_rounded;
        break;
      case 'dateRange':
        if (startDate != null) {
          label = '${startDate!.day}/${startDate!.month}';
          if (endDate != null && endDate != startDate) {
            label += ' - ${endDate!.day}/${endDate!.month}';
          }
          icon = Icons.calendar_today_rounded;
          break;
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }

    Color chipColor = primaryBlue;
    if (key == 'status') {
      chipColor = _getStatusColor(value);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeFilter(key),
            child: Icon(Icons.close_rounded, size: 14, color: chipColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBottomSheet() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: headerTextColor,
                  ),
                ),
                const Spacer(),
                if (activeFilters.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _clearAllFilters();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterFieldLabel('Details'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterInput(
                          controller: bookingIdController,
                          hint: 'Booking ID',
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterInput(
                          controller: customerIdController,
                          hint: 'Customer ID',
                          icon: Icons.person_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFilterFieldLabel('Engineer'),
                  const SizedBox(height: 12),
                  _buildDropdownFilter(
                    value: selectedEngineer,
                    items: engineerUsernames,
                    onChanged: (val) => setState(() => selectedEngineer = val!),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterFieldLabel('Status'),
                  const SizedBox(height: 12),
                  _buildDropdownFilter(
                    value: selectedStatus,
                    items: statusOptions,
                    onChanged: (val) => setState(() => selectedStatus = val!),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterFieldLabel('Date Range'),
                  const SizedBox(height: 12),
                  _buildDateRangePicker(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        FirestoreService.instance
                            .collection('Admin_details')
                            .get()
                            .then((snapshot) => _applyFilters(snapshot.docs));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: bodyTextColor,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildFilterInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: bodyTextColor.withOpacity(0.4),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, size: 18, color: primaryBlue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(color: headerTextColor, fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Row(
      children: [
        Expanded(child: _buildDatePickerBox(startDate, 'From', true)),
        const SizedBox(width: 12),
        Expanded(child: _buildDatePickerBox(endDate, 'To', false)),
      ],
    );
  }

  Widget _buildDatePickerBox(DateTime? date, String hint, bool isStart) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              startDate = picked;
            } else {
              endDate = picked;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
            const SizedBox(width: 10),
            Text(
              date != null ? '${date.day}/${date.month}/${date.year}' : hint,
              style: TextStyle(
                color: date != null
                    ? headerTextColor
                    : bodyTextColor.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading updates...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            filtersApplied
                ? "No matching updates found"
                : "No Engineer Updates",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtersApplied
                ? "Try adjusting your filters"
                : "Updates will appear here",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          if (filtersApplied)
            TextButton(
              onPressed: _clearAllFilters,
              child: Text(
                'Clear Filters',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EngineerUpdateCard extends StatefulWidget {
  final QueryDocumentSnapshot updateData;
  final int serialNumber;
  const EngineerUpdateCard(this.updateData, this.serialNumber, {super.key});

  @override
  _EngineerUpdateCardState createState() => _EngineerUpdateCardState();
}

class _EngineerUpdateCardState extends State<EngineerUpdateCard> {
  bool isExpanded = false;
  late TextEditingController statusDescController;
  late TextEditingController amountController;
  String selectedStatus = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.updateData.data() as Map<String, dynamic>;

    statusDescController = TextEditingController(
      text: data['statusDescription'] ?? '',
    );
    amountController = TextEditingController(
      text: data['amount']?.toString() ?? '0',
    );

    // SIMPLIFIED STATUS INITIALIZATION
    // Prefer engineerStatus, fallback to adminStatus, then default to 'Pending'
    String engineerStatus = data['engineerStatus']?.toString() ?? '';
    String adminStatus = data['adminStatus']?.toString() ?? '';

    if (engineerStatus.isNotEmpty) {
      selectedStatus = engineerStatus;
    } else if (adminStatus.isNotEmpty) {
      selectedStatus = adminStatus;
    } else {
      selectedStatus = 'Pending';
    }

    // Ensure the selected status is one of the valid options
    if (![
      'Pending',
      'In Progress',
      'Completed',
      'Unrepairable',
    ].contains(selectedStatus)) {
      selectedStatus = 'Pending';
    }
  }

  @override
  void didUpdateWidget(EngineerUpdateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updateData != widget.updateData) {
      final data = widget.updateData.data() as Map<String, dynamic>;
      if (!isLoading) {
        statusDescController.text = data['statusDescription'] ?? '';
        amountController.text = data['amount']?.toString() ?? '0';

        String engineerStatus = data['engineerStatus']?.toString() ?? '';
        String adminStatus = data['adminStatus']?.toString() ?? '';

        if (engineerStatus.isNotEmpty) {
          selectedStatus = engineerStatus;
        } else if (adminStatus.isNotEmpty) {
          selectedStatus = adminStatus;
        }

        // Ensure the selected status is one of the valid options
        if (![
          'Pending',
          'In Progress',
          'Completed',
          'Unrepairable',
        ].contains(selectedStatus)) {
          selectedStatus = 'Pending';
        }
      }
    }
  }

  @override
  void dispose() {
    statusDescController.dispose();
    amountController.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } else if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (e) {
      debugPrint('Error formatting timestamp: $e');
    }
    return 'N/A';
  }

  Future<void> updateFirestore(String action) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      DocumentReference docRef = FirestoreService.instance
          .collection('Admin_details')
          .doc(widget.updateData.id);

      // Get the original data to access customer details
      final originalData = widget.updateData.data() as Map<String, dynamic>;
      String customerPhoneNumber = originalData['mobileNumber'] ?? '';
      String bookingId = originalData['bookingId'] ?? '';
      String customerName = originalData['customerName'] ?? '';
      String customerId = originalData['id'] ?? originalData['Id'] ?? '';

      Map<String, dynamic> updateData = {
        'statusDescription': statusDescController.text,
        'amount': double.tryParse(amountController.text) ?? 0,
        // Add customer details for notification
        'mobileNumber': customerPhoneNumber,
        'bookingId': bookingId,
        'customerName': customerName,
      };

      // CORRECTED STATUS MAPPING LOGIC
      switch (action) {
        case 'Pending':
          updateData['engineerStatus'] = 'Pending';
          updateData['adminStatus'] = 'Pending';
          break;
        case 'In Progress':
          updateData['engineerStatus'] = 'In Progress';
          updateData['adminStatus'] = 'In Progress';
          break;
        case 'Completed':
          updateData['engineerStatus'] = 'Completed';
          updateData['adminStatus'] = 'Completed';
          break;
        case 'Unrepairable':
          updateData['engineerStatus'] = 'Unrepairable';
          updateData['adminStatus'] = 'Unrepairable';
          break;
        default:
          // Fallback for any unexpected status
          updateData['engineerStatus'] = action;
          updateData['adminStatus'] = action;
      }

      // Update the main document
      await docRef.update(updateData);

      // Also update the Engineer_updates collection
      QuerySnapshot existingDocs = await FirestoreService.instance
          .collection('Engineer_updates')
          .where('bookingId', isEqualTo: widget.updateData['bookingId'])
          .get();

      if (existingDocs.docs.isNotEmpty) {
        await existingDocs.docs.first.reference.update({
          'status': action,
          'statusDescription': statusDescController.text,
          'amount': double.tryParse(amountController.text) ?? 0,
        });
      } else {
        final data = widget.updateData.data() as Map<String, dynamic>;
        await FirestoreService.instance.collection('Engineer_updates').add({
          'bookingId': data['bookingId'] ?? 'N/A',
          'customerName': data['customerName'] ?? 'N/A',
          'deviceBrand': data['deviceBrand'] ?? 'N/A',
          'deviceCondition': data['deviceCondition'] ?? 'N/A',
          'assignedEmployee': data['assignedEmployee'] ?? 'N/A',
          'status': action,
          'statusDescription': statusDescController.text,
          'amount': double.tryParse(amountController.text) ?? 0,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Trigger in-app notification entry for customer
      try {
        await FirestoreService.instance.collection('notifications').add({
          'customerId': customerId,
          'customerName': customerName,
          'bookingId': bookingId,
          'title': 'Ticket Update',
          'body': 'Your ticket $bookingId status has been updated to $action.',
          'timestamp': FieldValue.serverTimestamp(),
          'seen': false,
        });
      } catch (e) {
        // Log but do not block UI
        debugPrint('Failed to create notification doc: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $action'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showConfirmationDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).primaryColor,
                size: 40,
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Update',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Change status to "$action"?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        updateFirestore(action);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color getStatusColor(String status) {
    final statusLower = status.toLowerCase().trim();

    if (statusLower == 'assigned' ||
        statusLower == 'completed' ||
        statusLower == 'complete' ||
        statusLower == 'delivered') {
      return Colors.green;
    }

    if (statusLower == 'not assigned' || statusLower == 'not assinged') {
      return Colors.red;
    }

    if (statusLower.contains('approval')) {
      return Colors.purple;
    }

    if (statusLower.contains('spare')) {
      return Colors.amber;
    }

    if (statusLower.contains('observation')) {
      return Colors.cyan;
    }

    if (statusLower == 'canceled' ||
        statusLower == 'cancelled' ||
        statusLower.contains('cancel')) {
      return Colors.grey;
    }

    if (statusLower == 'appointment') {
      return Colors.pink;
    }

    if (statusLower == 'open' ||
        statusLower == 'pending' ||
        statusLower.contains('progress')) {
      return Colors.orange;
    }

    if (statusLower == 'closed') {
      return Colors.blue;
    }

    return Colors.blueGrey;
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                child: Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 100,
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format payment data in bill format
  Widget _buildPaymentInfo(List<dynamic>? payments, Map<String, dynamic> data) {
    if (payments == null || payments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the main amount from document data
    final mainAmount = (data['amount'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Payment Information',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0B3470),
          ),
        ),
        const SizedBox(height: 12),

        // Bill-like container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bill header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B3470),
                      ),
                    ),
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B3470),
                      ),
                    ),
                  ],
                ),
              ),

              // Payment items
              ...payments.asMap().entries.map((entry) {
                final index = entry.key;
                final payment = entry.value as Map<String, dynamic>;
                final paymentMethod =
                    payment['paymentMethod']?.toString() ?? 'N/A';
                final paymentType = payment['paymentType']?.toString() ?? 'N/A';
                final amount = payment['amount']?.toString() ?? '0';
                final addedBy = payment['addedBy']?.toString() ?? 'N/A';
                final addedAt = _formatPaymentDate(payment['addedAt']);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: index == payments.length - 1
                            ? Colors.transparent
                            : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paymentMethod,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Type: $paymentType',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹$amount',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Added by $addedBy',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            addedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // Total section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      '₹${mainAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build Total Amount Section that shows on ALL tickets
  Widget _buildTotalAmountSection(Map<String, dynamic> data) {
    // Get the main amount from document data - handle all possible cases
    final amount = data['amount'];
    double mainAmount = 0;
    bool hasAmount = false;

    if (amount != null) {
      if (amount is num) {
        mainAmount = amount.toDouble();
        hasAmount = true;
      } else if (amount is String) {
        mainAmount = double.tryParse(amount) ?? 0;
        hasAmount = mainAmount > 0;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasAmount
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasAmount
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Amount:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: hasAmount
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
          ),
          Text(
            hasAmount ? '₹${mainAmount.toStringAsFixed(2)}' : 'No data found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: hasAmount ? 18 : 14,
              color: hasAmount
                  ? Theme.of(context).primaryColor
                  : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Build Field Images Section
  Widget _buildFieldImagesSection(Map<String, dynamic> data) {
    // Handle both 'images' and 'imageUrls' fields for backward compatibility
    final images = data['images'] as List<dynamic>? ?? [];
    final imageUrls = data['imageUrls'] as List<dynamic>? ?? [];

    // Combine both lists and remove duplicates
    final allImages = <dynamic>{...images, ...imageUrls}.toList();

    if (allImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Field Images',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0B3470),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Images captured during field visit:',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final imageUrl = allImages[idx];
              return GestureDetector(
                onTap: () {
                  _showImageDialog(context, imageUrl);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey[400],
                              size: 30,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Image ${idx + 1}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatPaymentDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      if (date is String) {
        // Parse ISO string format: "2025-10-09T11:24:58+05:30"
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
      } else if (date is Timestamp) {
        final parsedDate = date.toDate();
        return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.updateData.data() as Map<String, dynamic>;
    final assignedEmployee = data['assignedEmployee'] ?? 'Not Assigned';
    final customerId = data['id'] ?? 'N/A';
    final customerName = data['customerName'] ?? 'N/A';
    final payments = data['payments'] as List<dynamic>?;
    final bookingId = data['bookingId'] ?? 'N/A';
    final deviceBrand = data['deviceBrand'] ?? 'N/A';
    final deviceCondition = data['deviceCondition'] ?? 'No condition specified';
    final timestamp = data['timestamp'];

    // Determine status display for color
    String statusForColor = '';
    String engineerStatus = data['engineerStatus'] ?? '';
    String adminStatus = data['adminStatus'] ?? '';

    if (adminStatus.toLowerCase() == 'canceled' ||
        engineerStatus.toLowerCase() == 'canceled' ||
        engineerStatus.toLowerCase() == 'cancelled') {
      statusForColor = 'canceled';
    } else if (adminStatus.toLowerCase() == 'closed' ||
        adminStatus.toLowerCase() == 'delivered' ||
        engineerStatus.toLowerCase() == 'delivered') {
      statusForColor = 'delivered';
    } else if (engineerStatus.isNotEmpty) {
      statusForColor = engineerStatus;
    } else if (adminStatus.isNotEmpty) {
      statusForColor = adminStatus;
    } else {
      statusForColor = 'Pending';
    }

    // Map status for display
    String displayStatus = statusForColor;
    final lowerStatus = statusForColor.toLowerCase().trim();
    if (lowerStatus == 'pfa' || lowerStatus.contains('approval')) {
      displayStatus = 'Pending for Approval';
    } else if (lowerStatus == 'pfs' || lowerStatus.contains('spare')) {
      displayStatus = 'Pending for Spares';
    } else if (lowerStatus.contains('observation')) {
      displayStatus = 'Observation';
    } else if (lowerStatus == 'delivered' ||
        lowerStatus == 'complete' ||
        lowerStatus == 'completed') {
      displayStatus = 'Completed';
    } else if (lowerStatus == 'open' || lowerStatus == 'assigned') {
      displayStatus = 'Assigned';
    } else if (lowerStatus == 'canceled' || lowerStatus == 'cancelled') {
      displayStatus = 'Canceled';
    } else if (lowerStatus.contains('progress')) {
      displayStatus = 'In Progress';
    } else if (statusForColor.length > 2) {
      displayStatus =
          statusForColor[0].toUpperCase() +
          statusForColor.substring(1).toLowerCase();
    }

    final Color statusColor = getStatusColor(statusForColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header Section
            InkWell(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Serial Number / Index
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.serialNumber.toString(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ID and Customer Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookingId,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Chip
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            displayStatus.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded) ...[
              const Divider(height: 1, indent: 20, endIndent: 20),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Details Grid
                    _buildInfoGrid([
                      {
                        'label': 'Customer ID',
                        'value': customerId,
                        'icon': Icons.person_outline_rounded,
                      },
                      {
                        'label': 'Device',
                        'value': deviceBrand,
                        'icon': Icons.devices_rounded,
                      },
                      {
                        'label': 'Engineer',
                        'value': assignedEmployee,
                        'icon': Icons.engineering_outlined,
                      },
                      {
                        'label': 'Date',
                        'value': _formatTimestamp(timestamp),
                        'icon': Icons.calendar_today_rounded,
                      },
                    ]),

                    const SizedBox(height: 24),
                    _buildSectionTitle('Issue & Notes'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.05),
                        ),
                      ),
                      child: Text(
                        deviceCondition,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),

                    if (data['description'] != null &&
                        data['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Engineer Notes'),
                      const SizedBox(height: 8),
                      Text(
                        data['description'],
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // Payment and Amount Sections
                    if (payments != null && payments.isNotEmpty)
                      _buildPaymentInfo(payments, data)
                    else
                      _buildTotalAmountSection(data),

                    // Field Images
                    _buildFieldImagesSection(data),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Update Status'),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Select New Status',
                          ),
                          items:
                              [
                                    'Assigned',
                                    'Pending',
                                    'In Progress',
                                    'Pending for Approval',
                                    'Pending for Spares',
                                    'Observation',
                                    'Completed',
                                    'Canceled',
                                    'Unrepairable',
                                  ]
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => selectedStatus = value!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description Input
                    TextField(
                      controller: statusDescController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        hintText: 'Add internal status description...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: ThemeService.instance.primaryColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _showConfirmationDialog(selectedStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeService.instance.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Update Ticket Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
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
  }

  // New Helper Widgets
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: ThemeService.instance.primaryColor.withOpacity(0.9),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildInfoGrid(List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items
          .map(
            (item) => SizedBox(
              width: (MediaQuery.of(context).size.width - 100) / 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 16,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['label'].toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item['value'].toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
