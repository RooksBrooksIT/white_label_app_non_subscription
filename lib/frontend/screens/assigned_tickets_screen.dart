import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart'; // For ProfessionalTheme
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class AssignedTicketsScreen extends StatelessWidget {
  final String engineerName;

  const AssignedTicketsScreen({super.key, required this.engineerName});

  @override
  Widget build(BuildContext context) {
    final stream = FirestoreService.instance
        .collection('Admin_ticket_entry')
        .where(
          Filter.or(
            Filter('assignedEmployee', isEqualTo: engineerName),
            Filter('assignedEngineer', isEqualTo: engineerName),
            Filter('helperName', isEqualTo: engineerName),
            Filter('Helper1', isEqualTo: engineerName),
            Filter('helper', isEqualTo: engineerName),
          ),
        )
        .snapshots();

    return Scaffold(
      backgroundColor: ProfessionalTheme.background(context),
      appBar: AppBar(
        automaticallyImplyLeading: !kIsWeb,
        title: const Text(
          'Assigned Tickets',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: ProfessionalTheme.primary(context),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: ResponsiveWrapper(
        maxWidth: 960,
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(context);
            }

            final docs = snapshot.data!.docs;
            final seenIds = <String>{};
            final assignedDocs = <QueryDocumentSnapshot>[];
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final bId = (data['bookingId'] ?? d.id).toString();
              if (seenIds.add(bId)) {
                final status =
                    (data['engineerStatus'] ?? data['adminStatus'] ?? '')
                        .toString()
                        .toLowerCase();
                if (status != 'completed') {
                  assignedDocs.add(d);
                }
              }
            }

            if (assignedDocs.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: assignedDocs.length,
              itemBuilder: (context, index) {
                final doc = assignedDocs[index];
                return _buildTicketCard(context, doc);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_rounded,
            size: 64,
            color: ProfessionalTheme.borderLight(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No assigned tickets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ProfessionalTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, QueryDocumentSnapshot doc) {
    final booking = AdminDetails.fromFirestore(doc);
    final data = doc.data() as Map<String, dynamic>;
    final customerName = booking.customerName.isNotEmpty
        ? booking.customerName
        : 'Customer';
    final serviceName =
        (booking.deviceBrand.isNotEmpty
                ? '${booking.deviceBrand} ${booking.deviceType}'.trim()
                : (data['serviceName'] ??
                      data['workName'] ??
                      (booking.deviceType.isNotEmpty
                          ? booking.deviceType
                          : 'Service')))
            .toString();
    final address = booking.address.isNotEmpty
        ? booking.address
        : 'Address not available';
    final status = booking.selectedStatus.isNotEmpty
        ? booking.selectedStatus
        : 'Assigned';
    final bookingId = booking.bookingId.isNotEmpty ? booking.bookingId : 'N/A';

    final isHelper = booking.isHelperAssignment(engineerName);
    final isPrimary = booking.isPrimaryAssignment(engineerName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ProfessionalTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfessionalTheme.borderLight(context)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TicketDetailScreen(booking: booking, userName: engineerName),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isHelper
                          ? const Color(0xFFFEF3C7)
                          : ProfessionalTheme.primaryExtraLight(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isHelper
                          ? Icons.handshake_rounded
                          : Icons.assignment_rounded,
                      color: isHelper
                          ? const Color(0xFFD97706)
                          : ProfessionalTheme.primary(context),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                customerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: ProfessionalTheme.textPrimary(context),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (booking.isCanceled) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cancel_rounded,
                                      size: 10,
                                      color: Color(0xFFDC2626),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'CANCELLED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isHelper) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: Color(0xFFD97706),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'HELPER ASSIGNED (READ-ONLY)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isPrimary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF3B82F6,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.badge_rounded,
                                      size: 10,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'PRIMARY ENGINEER',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serviceName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ProfessionalTheme.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: booking.isCanceled
                          ? const Color(0xFFFEF2F2)
                          : ProfessionalTheme.primaryExtraLight(context),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: booking.isCanceled
                            ? const Color(0xFFFCA5A5)
                            : ProfessionalTheme.borderLight(context),
                      ),
                    ),
                    child: Text(
                      booking.isCanceled ? 'CANCELLED' : status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: booking.isCanceled
                            ? const Color(0xFFDC2626)
                            : ProfessionalTheme.primary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.tag_rounded,
                text: 'ID: $bookingId',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(context, icon: Icons.place_rounded, text: address),
              if (booking.hasVisitSchedule) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  icon: Icons.event_available_rounded,
                  text: 'Expected Visit: ${booking.formattedVisitSchedule}',
                  iconColor: const Color(0xFF16A34A),
                  textColor: const Color(0xFF15803D),
                  isBold: true,
                ),
              ],
              if (booking.visitNotes.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  context,
                  icon: Icons.notes_rounded,
                  text: 'Notes: ${booking.visitNotes}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? textColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? ProfessionalTheme.textTertiary(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor ?? ProfessionalTheme.textSecondary(context),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
