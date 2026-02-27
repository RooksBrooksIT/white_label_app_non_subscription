import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/pdf_utils.dart';

class AdminEngineerReports extends StatefulWidget {
  const AdminEngineerReports({super.key});

  @override
  _AdminEngineerReportsState createState() => _AdminEngineerReportsState();
}

class _AdminEngineerReportsState extends State<AdminEngineerReports>
    with SingleTickerProviderStateMixin {
  String? selectedEngineer;
  bool isDateFilterEnabled = false;
  DateTime? selectedDate;
  DateTime? fromDate;
  DateTime? toDate;
  bool isDateRangeMode = false;

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, Map<String, int>> engineerStatusCounts = {};
  Set<String> allStatuses = {};

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: isMobile ? 120 : 150,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: EdgeInsets.only(
                  left: isMobile ? 60 : 80,
                  bottom: 16,
                ),
                title: Row(
                  children: [
                    if (isDesktop) ...[
                      Icon(
                        Icons.analytics_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Engineer Performance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (!isMobile)
                          Text(
                            'Real-time analytics and performance metrics',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Main Content
          SliverPadding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Filter Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFilterSection(isMobile, isTablet, isDesktop),
                ),

                const SizedBox(height: 24),

                // Results Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: adminDetailsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildLoadingState(isMobile);
                      }
                      if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error.toString());
                      }

                      engineerStatusCounts.clear();
                      allStatuses.clear();

                      final docs = snapshot.data!.docs;
                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        String? rawEngineerName = data['assignedEmployee']
                            ?.toString();
                        if (rawEngineerName != null) {
                          final engineerName = rawEngineerName
                              .trim()
                              .toLowerCase();
                          final rawStatus =
                              data['adminStatus']?.toString() ?? '';
                          final normalizedStatus = _normalizeStatusKey(
                            rawStatus,
                          );

                          allStatuses.add(normalizedStatus);

                          engineerStatusCounts.putIfAbsent(
                            engineerName,
                            () => {},
                          );
                          final engineerMap =
                              engineerStatusCounts[engineerName]!;
                          engineerMap[normalizedStatus] =
                              (engineerMap[normalizedStatus] ?? 0) + 1;
                        }
                      }

                      if (selectedEngineer != null) {
                        final selectedCounts =
                            engineerStatusCounts[selectedEngineer!
                                .toLowerCase()];

                        if (selectedCounts == null || selectedCounts.isEmpty) {
                          return _buildEmptyState(isMobile);
                        }

                        final totalTickets = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final assignedEmployee = data['assignedEmployee']
                              ?.toString()
                              .trim()
                              .toLowerCase();
                          final timestamp = _parseTimestamp(data['timestamp']);
                          if (selectedEngineer == null) return false;
                          bool matchesEngineer =
                              assignedEmployee ==
                              selectedEngineer!.toLowerCase();
                          bool matchesDate = _matchesDateFilter(timestamp);
                          return matchesEngineer && matchesDate;
                        }).length;

                        return _buildDashboard(
                          context,
                          selectedCounts,
                          totalTickets,
                          docs,
                          isMobile,
                          isTablet,
                          isDesktop,
                        );
                      } else {
                        return _buildWelcomeState(isMobile);
                      }
                    },
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isMobile, bool isTablet, bool isDesktop) {
    bool isDropdownDisabled =
        isDateFilterEnabled &&
        ((!isDateRangeMode && selectedDate == null) ||
            (isDateRangeMode && (fromDate == null || toDate == null)));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.filter_alt_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Filter Performance Metrics',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Responsive filter layout
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildDateFilterControls(isMobile)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 3,
                  child: _buildEngineerSelector(isDropdownDisabled, isMobile),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildDateFilterControls(isMobile),
                const SizedBox(height: 20),
                _buildEngineerSelector(isDropdownDisabled, isMobile),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateFilterControls(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date filter toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: isDateFilterEnabled
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Filter by Date',
                  style: TextStyle(
                    color: _getContrastColor(Theme.of(context).cardColor),
                    fontWeight: FontWeight.w600,
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
                      selectedEngineer = null;
                    }
                  });
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),

        if (isDateFilterEnabled) ...[
          const SizedBox(height: 12),

          // Date range toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                isDateRangeMode ? 'Date Range' : 'Single Date',
                style: TextStyle(
                  color: _getContrastColor(
                    Theme.of(context).cardColor,
                  ).withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: Switch.adaptive(
                  value: isDateRangeMode,
                  onChanged: (bool? newValue) {
                    setState(() {
                      isDateRangeMode = newValue ?? false;
                      selectedDate = null;
                      fromDate = null;
                      toDate = null;
                      selectedEngineer = null;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date pickers
          if (!isDateRangeMode)
            _buildDatePicker('Select Date', selectedDate, (pickedDate) {
              setState(() {
                selectedDate = pickedDate;
                selectedEngineer = null;
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
                      selectedEngineer = null;
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
                        selectedEngineer = null;
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
          'Select Engineer',
          style: TextStyle(
            color: _getContrastColor(
              Theme.of(context).cardColor,
            ).withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<String>>(
          stream: getEngineerUsernames(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LinearProgressIndicator());
            }

            final engineers = snapshot.data ?? [];
            final items = engineers
                .map(
                  (eng) => DropdownMenuItem<String>(
                    value: eng,
                    child: Text(
                      eng[0].toUpperCase() +
                          (eng.length > 1 ? eng.substring(1) : ''),
                      style: TextStyle(
                        color: _getContrastColor(Theme.of(context).cardColor),
                      ),
                    ),
                  ),
                )
                .toList();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDropdownDisabled
                      ? Colors.grey.withOpacity(0.2)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: Theme.of(context).cardColor,
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
                              : 'Choose engineer',
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
            color: _getContrastColor(Theme.of(context).cardColor),
            fontSize: isMobile ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
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
                      onPrimary: _getContrastColor(
                        Theme.of(context).primaryColor,
                      ),
                      surface: Theme.of(context).cardColor,
                      onSurface: _getContrastColor(Theme.of(context).cardColor),
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
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentDate == null
                        ? 'Select date'
                        : '${currentDate.day}/${currentDate.month}/${currentDate.year}',
                    style: TextStyle(
                      color: currentDate == null
                          ? Colors.grey.shade500
                          : _getContrastColor(Theme.of(context).cardColor),
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
        // KPI Cards
        _buildKPICards(totalTickets, docs, isMobile),

        const SizedBox(height: 32),

        // Status Breakdown Header with Export
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Status Breakdown',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (!isMobile) _buildExportButton(docs, isMobile),
          ],
        ),

        const SizedBox(height: 24),

        // Status Grid
        _buildStatusGrid(selectedCounts, isMobile, isTablet),

        const SizedBox(height: 24),

        // Mobile Export Button
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildExportButton(docs, isMobile),
          ),

        // Reset Button
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                selectedEngineer = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Clear Selection'),
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
    // Calculate metrics
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: [
        _buildKPICard(
          'Total Tasks',
          totalTickets.toString(),
          Icons.assignment_rounded,
          Colors.blue,
        ),
        _buildKPICard(
          'Completed',
          completedTickets.toString(),
          Icons.check_circle_rounded,
          Colors.green,
        ),
        _buildKPICard(
          'Completion Rate',
          '$completionRate%',
          Icons.trending_up_rounded,
          Colors.orange,
        ),
        _buildKPICard(
          'Total Revenue',
          '₹${totalAmount.toStringAsFixed(0)}',
          Icons.currency_rupee_rounded,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
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
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
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
              borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      },
      icon: Icon(Icons.picture_as_pdf_rounded, size: isMobile ? 18 : 20),
      label: Text(isMobile ? 'PDF' : 'Export PDF Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 24,
          vertical: isMobile ? 12 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
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
            const SizedBox(height: 16),
            Text(
              'Loading performance data...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isMobile ? 14 : 16,
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 48,
              color: Colors.orange.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Data Found',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No tickets found for this engineer\nwith the selected filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Performance Analytics',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select an engineer and apply filters\nto view detailed performance metrics',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isMobile ? 14 : 16,
              height: 1.5,
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

  // Updated PDF Generation - Only Detailed Ticket Analysis section
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
            // Engineer Information Header
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

            // Detailed Ticket Analysis Header
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

            // Tickets Table
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

  // Helper methods for PDF (kept for reference)
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

  Color _getContrastColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
  }
}
