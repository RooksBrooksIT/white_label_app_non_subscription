import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_dashboard_page.dart'; // For ProfessionalTheme

class AssignedTicketsScreen extends StatelessWidget {
  final String engineerName;

  const AssignedTicketsScreen({super.key, required this.engineerName});

  @override
  Widget build(BuildContext context) {
    final stream = FirestoreService.instance
        .collection('Admin_details')
        .where('assignedEmployee', isEqualTo: engineerName)
        .snapshots();

    return Scaffold(
      backgroundColor: ProfessionalTheme.background(context),
      appBar: AppBar(
        title: const Text(
          'Assigned Tickets',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: ProfessionalTheme.primary(context),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final docs = snapshot.data!.docs;
          final assignedDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final status =
                (data['engineerStatus'] ?? '').toString().toLowerCase();
            return status != 'completed';
          }).toList();

          if (assignedDocs.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignedDocs.length,
            itemBuilder: (context, index) {
              final doc = assignedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildTicketCard(context, data);
            },
          );
        },
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

  Widget _buildTicketCard(BuildContext context, Map<String, dynamic> data) {
    final customerName = (data['customerName'] ?? 'Customer').toString();
    final serviceName = (data['deviceBrand'] ??
            data['serviceName'] ??
            data['workName'] ??
            data['deviceType'] ??
            'Service')
        .toString();
    final address = (data['address'] ?? 'Address not available').toString();
    final status = (data['engineerStatus'] ?? data['adminStatus'] ?? 'Assigned')
        .toString();
    final bookingId = (data['bookingId'] ?? 'N/A').toString();
    final assignedDate = (data['assignedDate'] ?? 'Unknown date').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ProfessionalTheme.primaryExtraLight(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: ProfessionalTheme.primary(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                  color: ProfessionalTheme.primaryExtraLight(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: ProfessionalTheme.borderLight(context),
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: ProfessionalTheme.primary(context),
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
          _buildInfoRow(
            context,
            icon: Icons.calendar_today_rounded,
            text: 'Assigned: $assignedDate',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            icon: Icons.place_rounded,
            text: address,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: ProfessionalTheme.textTertiary(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: ProfessionalTheme.textSecondary(context),
              fontWeight: FontWeight.w500,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
