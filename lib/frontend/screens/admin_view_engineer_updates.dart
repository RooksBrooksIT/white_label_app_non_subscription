import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class EngineerUpdates extends StatefulWidget {
  const EngineerUpdates({super.key});

  @override
  State<EngineerUpdates> createState() => _EngineerUpdatesState();
}

class _EngineerUpdatesState extends State<EngineerUpdates> {
  String selectedFilter = 'All';
  String selectedEngineer = 'All Engineers';
  List<String> engineerUsernames = ['All Engineers'];
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  final List<String> statusFilterOptions = [
    'All',
    'Not Assigned',
    'Assigned',
    'In Progress',
    'Pending',
    'Pending for Approval',
    'Pending for Spares',
    'Observation',
    'Completed',
    'Canceled',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEngineerUsernames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      if (mounted) {
        setState(() {
          engineerUsernames = usernames;
        });
      }
    } catch (_) {}
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'assigned') return const Color(0xFF0984E3);
    if (s == 'completed' || s == 'complete' || s == 'delivered')
      return const Color(0xFF10B981);
    if (s == 'not assigned' || s == 'not assinged')
      return const Color(0xFFEF4444);
    if (s.contains('approval')) return const Color(0xFF8B5CF6);
    if (s.contains('spare')) return const Color(0xFFF59E0B);
    if (s.contains('observation')) return const Color(0xFF06B6D4);
    if (s == 'canceled' || s == 'cancelled') return const Color(0xFF64748B);
    if (s == 'in progress' || s.contains('progress'))
      return const Color(0xFF3B82F6);
    if (s == 'pending' || s == 'open') return const Color(0xFFF97316);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
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
        title: Text(
          'Engineer Updates',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color:
                      selectedFilter != 'All' ||
                          selectedEngineer != 'All Engineers'
                      ? primaryColor
                      : const Color(0xFF0F172A),
                ),
                onPressed: _showFilterBottomSheet,
              ),
              if (selectedFilter != 'All' ||
                  selectedEngineer != 'All Engineers')
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ResponsiveWrapper(
        maxWidth: kMaxContentWidth,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopDomainBanner(primaryColor),
              const SizedBox(height: 8),
              _buildSearchBar(primaryColor),
              const SizedBox(height: 12),
              _buildQuickFilterChips(primaryColor),
              const SizedBox(height: 12),
              Expanded(child: _buildUpdatesStream(primaryColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopDomainBanner(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.engineering_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Engineer Workspace',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track live status, field notes & job progress',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Search Booking ID, Customer, or Mobile...',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (val) {
            setState(() {
              searchQuery = val.trim().toLowerCase();
            });
          },
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips(Color primaryColor) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: statusFilterOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = statusFilterOptions[index];
          final isSelected = selectedFilter == option;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = option;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpdatesStream(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.instance
          .collection('Admin_ticket_entry')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading updates: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final bookingId = (data['bookingId'] ?? '').toString().toLowerCase();
          final customerName = (data['customerName'] ?? '')
              .toString()
              .toLowerCase();
          final mobile = (data['mobileNumber'] ?? '').toString().toLowerCase();
          final assignedEngineer = (data['assignedEmployee'] ?? '')
              .toString()
              .toLowerCase();
          final engineerStatus =
              (data['engineerStatus'] ?? data['adminStatus'] ?? 'Pending')
                  .toString();

          if (searchQuery.isNotEmpty) {
            if (!bookingId.contains(searchQuery) &&
                !customerName.contains(searchQuery) &&
                !mobile.contains(searchQuery) &&
                !assignedEngineer.contains(searchQuery)) {
              return false;
            }
          }

          if (selectedFilter != 'All') {
            if (engineerStatus.toLowerCase().trim() !=
                selectedFilter.toLowerCase().trim()) {
              return false;
            }
          }

          if (selectedEngineer != 'All Engineers') {
            if (assignedEngineer != selectedEngineer.toLowerCase()) {
              return false;
            }
          }

          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 48,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Engineer Updates Found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try adjusting search query or filter chips.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildCleanTicketCard(
              filtered[index],
              index + 1,
              primaryColor,
            );
          },
        );
      },
    );
  }

  Widget _buildCleanTicketCard(
    QueryDocumentSnapshot doc,
    int serialNumber,
    Color primaryColor,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final bookingId = (data['bookingId'] ?? doc.id).toString();
    final customerName = (data['customerName'] ?? 'Unknown Customer')
        .toString();
    final assignedEngineer = (data['assignedEmployee'] ?? 'Not Assigned')
        .toString();
    final deviceBrand =
        (data['deviceBrand'] ?? data['deviceType'] ?? 'Hardware Device')
            .toString();
    final deviceCondition =
        (data['deviceCondition'] ?? data['description'] ?? 'General Service')
            .toString();
    final status = (data['engineerStatus'] ?? data['adminStatus'] ?? 'Pending')
        .toString();
    final statusColor = _getStatusColor(status);
    final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);

    final rawTs = data['timestamp'] ?? data['lastUpdated'];
    String dateStr = 'Today';
    if (rawTs is Timestamp) {
      dateStr = DateFormat('dd MMM, hh:mm a').format(rawTs.toDate());
    }

    final isDelivery = bookingId.toUpperCase().startsWith('D');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showTicketDetailModal(doc, statusColor, primaryColor),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDelivery
                            ? const Color(0xFFECFDF5)
                            : statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isDelivery
                            ? Icons.local_shipping_rounded
                            : Icons.build_circle_rounded,
                        color: isDelivery
                            ? const Color(0xFF10B981)
                            : statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                bookingId,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customerName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                // Info Pills Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPill(
                      Icons.person_rounded,
                      assignedEngineer,
                      assignedEngineer.toLowerCase() == 'not assigned'
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF3B82F6),
                    ),
                    _buildPill(
                      Icons.devices_rounded,
                      deviceBrand,
                      const Color(0xFF64748B),
                    ),
                    _buildPill(
                      Icons.access_time_rounded,
                      dateStr,
                      const Color(0xFF94A3B8),
                    ),
                  ],
                ),

                if (deviceCondition.isNotEmpty &&
                    deviceCondition.toLowerCase() != 'n/a') ...[
                  const SizedBox(height: 10),
                  Text(
                    deviceCondition,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF475569),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildCardImageThumbnails(imageUrls),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardImageThumbnails(List<String> imageUrls) {
    final displayUrls = imageUrls.length > 3
        ? imageUrls.sublist(0, 3)
        : imageUrls;
    final remainingCount = imageUrls.length - displayUrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 13,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              '${imageUrls.length} Photo${imageUrls.length == 1 ? '' : 's'} Uploaded',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayUrls.length + (remainingCount > 0 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == displayUrls.length) {
                return GestureDetector(
                  onTap: () {
                    _showImagesGalleryDialog(imageUrls);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        '+$remainingCount',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final url = displayUrls[index];
              return GestureDetector(
                onTap: () => _showFullImageDialog(url),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF94A3B8),
                              size: 24,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showTicketDetailModal(
    QueryDocumentSnapshot doc,
    Color statusColor,
    Color primaryColor,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final bookingId = (data['bookingId'] ?? doc.id).toString();
    final customerName = (data['customerName'] ?? 'Unknown Customer')
        .toString();
    final customerPhone = (data['mobileNumber'] ?? 'N/A').toString();
    final customerId = (data['id'] ?? data['Id'] ?? 'N/A').toString();
    final address = (data['address'] ?? 'N/A').toString();
    final assignedEngineer = (data['assignedEmployee'] ?? 'Not Assigned')
        .toString();
    final deviceBrand =
        (data['deviceBrand'] ?? data['deviceType'] ?? 'Hardware Device')
            .toString();
    final deviceCondition =
        (data['deviceCondition'] ?? data['problem'] ?? 'N/A').toString();
    final notes = (data['statusDescription'] ?? data['description'] ?? '')
        .toString();
    String currentStatus =
        (data['engineerStatus'] ?? data['adminStatus'] ?? 'Pending').toString();
    final List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);

    final bool isDelivery =
        bookingId.toUpperCase().startsWith('D') ||
        (data['jobType'] ?? '').toString().toLowerCase().trim() == 'delivery';

    final notesController = TextEditingController(text: notes);
    final amountController = TextEditingController(
      text: (data['amount']?.toString() ?? '0'),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final List<String> availableStatuses;
            if (isDelivery) {
              availableStatuses = <String>['Delivered', 'Not Delivered'];
            } else {
              availableStatuses = <String>[
                'Not Assigned',
                'Assigned',
                'In Progress',
                'Pending',
                'Pending for Approval',
                'Pending for Spares',
                'Observation',
                'Completed',
                'Canceled',
                'Unrepairable',
              ];
            }
            if (!availableStatuses.contains(currentStatus)) {
              availableStatuses.add(currentStatus);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.build_circle_rounded,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket #$bookingId',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              customerName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Details Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                _modalDetailRow('Customer ID', customerId),
                                _modalDetailRow('Phone Number', customerPhone),
                                _modalDetailRow('Device Brand', deviceBrand),
                                _modalDetailRow(
                                  'Assigned To',
                                  assignedEngineer,
                                ),
                                if (address != 'N/A')
                                  _modalDetailRow('Address', address),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          Text(
                            'Reported Issue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              deviceCondition,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Text(
                            'Update Ticket Status',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),

                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Status',
                              labelStyle: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            initialValue: currentStatus,
                            items: availableStatuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  currentStatus = val;
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 14),

                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Engineer / Admin Notes',
                              labelStyle: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 13.5),
                          ),

                          const SizedBox(height: 14),

                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount (₹)',
                              labelStyle: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 13.5),
                          ),

                          const SizedBox(height: 24),
                          _buildModalImageGallerySection(imageUrls),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final newAmount =
                              double.tryParse(amountController.text) ?? 0;
                          final newDescription = notesController.text.trim();
                          final newStatus = currentStatus;
                          await doc.reference.update({
                            'engineerStatus': newStatus,
                            'adminStatus': newStatus,
                            'statusDescription': newDescription,
                            'amount': newAmount,
                            'lastUpdated': FieldValue.serverTimestamp(),
                          });

                          try {
                            final raisedRef = FirestoreService.instance
                                .collection('Raised_tickets');
                            final syncTicketId =
                                (data['ticketId'] ??
                                        data['bookingId'] ??
                                        doc.id)
                                    .toString();

                            // 1) Try to find a matching doc by ticketId / bookingId
                            QuerySnapshot match = await raisedRef
                                .where(
                                  Filter.or(
                                    Filter('ticketId', isEqualTo: syncTicketId),
                                    Filter(
                                      'bookingId',
                                      isEqualTo: syncTicketId,
                                    ),
                                  ),
                                )
                                .limit(1)
                                .get();

                            DocumentReference? raisedDocRef;
                            if (match.docs.isNotEmpty) {
                              raisedDocRef = match.docs.first.reference;
                            } else {
                              // 2) Fallback: try to match by customer id +
                              //    created timestamp + customerName
                              final cId =
                                  (customerId ??
                                          data['customerid'] ??
                                          data['id'] ??
                                          '')
                                      .toString();
                              final cName = (data['customerName'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              if (cId.isNotEmpty || cName.isNotEmpty) {
                                QuerySnapshot fallbacks = await raisedRef
                                    .limit(200)
                                    .get();
                                for (final d in fallbacks.docs) {
                                  final m = d.data() as Map<String, dynamic>;
                                  final docCId =
                                      (m['customerid'] ??
                                              m['id'] ??
                                              m['customerId'] ??
                                              '')
                                          .toString()
                                          .trim();
                                  final docCName = (m['customerName'] ?? '')
                                      .toString()
                                      .trim()
                                      .toLowerCase();
                                  final docTicketId =
                                      (m['ticketId'] ?? m['bookingId'] ?? '')
                                          .toString();
                                  if ((cId.isNotEmpty && docCId == cId) ||
                                      (cName.isNotEmpty && docCName == cName)) {
                                    if (docTicketId.isEmpty ||
                                        docTicketId == syncTicketId) {
                                      raisedDocRef = d.reference;
                                      break;
                                    }
                                  }
                                }
                              }
                            }

                            if (raisedDocRef != null) {
                              final Map<String, dynamic> syncData = {
                                'engineerStatus': newStatus,
                                'adminStatus': newStatus,
                                'statusDescription': newDescription,
                                'description': newDescription,
                                'amount': newAmount,
                                'paymentDetails': newAmount.toString(),
                                'lastUpdated': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              };
                              try {
                                await raisedDocRef.update(syncData);
                              } catch (_) {
                                await raisedDocRef.set(
                                  syncData,
                                  SetOptions(merge: true),
                                );
                              }
                            }
                          } catch (_) {}

                          try {
                            await NotificationService.sendNotificationToFirestore(
                              audience: 'customer',
                              customerId: customerId,
                              customerName: customerName,
                              bookingId: bookingId,
                              title: 'Ticket Status Updated',
                              body:
                                  'Your ticket #$bookingId status has been updated to "$currentStatus".',
                              type: 'status_update',
                            );
                          } catch (_) {}

                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Status updated to $currentStatus',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error updating: $e'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Save & Apply Update',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _modalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalImageGallerySection(List<String> imageUrls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.photo_camera_front_rounded,
                color: Color(0xFF6366F1),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Engineer Uploaded Photos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    imageUrls.isEmpty
                        ? 'No photos submitted yet'
                        : '${imageUrls.length} photo${imageUrls.length == 1 ? '' : 's'} attached',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (imageUrls.isNotEmpty)
              TextButton.icon(
                onPressed: () => _showImagesGalleryDialog(imageUrls),
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (imageUrls.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.no_photography_outlined,
                    size: 36,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No photos yet',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Engineer has not uploaded any photos for this ticket.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: imageUrls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final url = imageUrls[index];
              return GestureDetector(
                onTap: () => _showFullImageDialog(url),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 32,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Failed to load',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagesGalleryDialog(List<String> imageUrls) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF818CF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Photos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${imageUrls.length} photo${imageUrls.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: imageUrls.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final url = imageUrls[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showFullImageDialog(url);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF1E293B),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Color(0xFF64748B),
                                    size: 28,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: const Color(0xFF1E293B),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Engineer Updates',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Filter by Engineer',
                  labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                initialValue: selectedEngineer,
                items: engineerUsernames
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    selectedEngineer = val ?? 'All Engineers';
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      selectedFilter = 'All';
                      selectedEngineer = 'All Engineers';
                      _searchController.clear();
                      searchQuery = '';
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Reset All Filters',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
