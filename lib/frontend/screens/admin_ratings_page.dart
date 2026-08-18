import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class AdminRatingsPage extends StatefulWidget {
  const AdminRatingsPage({super.key});

  @override
  State<AdminRatingsPage> createState() => _AdminRatingsPageState();
}

class _AdminRatingsPageState extends State<AdminRatingsPage> {
  int _selectedStarFilter = 0; // 0 = All, 1..5 = filter by stars
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text(
          'Customer Ratings & Feedback',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.instance
            .collection('ratings')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final allRatings = allDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return {
              ...data,
              'id': doc.id,
            };
          }).toList();

          // Calculate summary metrics
          double totalRatingSum = 0;
          Map<int, int> starCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

          for (final r in allRatings) {
            final ratingVal = (r['rating'] as num?)?.toDouble() ?? 5.0;
            totalRatingSum += ratingVal;
            final roundedStar = ratingVal.round().clamp(1, 5);
            starCounts[roundedStar] = (starCounts[roundedStar] ?? 0) + 1;
          }

          final double averageRating = allRatings.isNotEmpty
              ? totalRatingSum / allRatings.length
              : 0.0;

          // Filter ratings based on star filter and search query
          final filteredRatings = allRatings.where((r) {
            final ratingVal = (r['rating'] as num?)?.toDouble() ?? 5.0;
            final roundedStar = ratingVal.round().clamp(1, 5);

            if (_selectedStarFilter > 0 && roundedStar != _selectedStarFilter) {
              return false;
            }

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final cName = (r['customerName'] ?? '').toString().toLowerCase();
              final tId = (r['ticketId'] ?? r['bookingId'] ?? '').toString().toLowerCase();
              final comment = (r['comment'] ?? '').toString().toLowerCase();
              final engName = (r['engineerName'] ?? '').toString().toLowerCase();

              if (!cName.contains(q) &&
                  !tId.contains(q) &&
                  !comment.contains(q) &&
                  !engName.contains(q)) {
                return false;
              }
            }

            return true;
          }).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Summary Metric Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _buildSummaryCard(
                    averageRating: averageRating,
                    totalReviews: allRatings.length,
                    starCounts: starCounts,
                    primaryColor: primaryColor,
                  ),
                ),
              ),

              // Search Bar & Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search by customer, ticket, or engineer...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('All', 0, allRatings.length),
                            _buildFilterChip('5 Stars', 5, starCounts[5] ?? 0),
                            _buildFilterChip('4 Stars', 4, starCounts[4] ?? 0),
                            _buildFilterChip('3 Stars', 3, starCounts[3] ?? 0),
                            _buildFilterChip('2 Stars', 2, starCounts[2] ?? 0),
                            _buildFilterChip('1 Star', 1, starCounts[1] ?? 0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Reviews List or Empty State
              if (filteredRatings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 64,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Ratings Found',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty || _selectedStarFilter > 0
                              ? 'Try adjusting your search or star filters'
                              : 'Customer feedback for completed services will appear here.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = filteredRatings[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildReviewCard(r, primaryColor),
                        );
                      },
                      childCount: filteredRatings.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required double averageRating,
    required int totalReviews,
    required Map<int, int> starCounts,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Score & Star Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                totalReviews > 0 ? averageRating.toStringAsFixed(1) : '0.0',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final fillPercent = (averageRating - index).clamp(0.0, 1.0);
                  return Icon(
                    fillPercent >= 0.8
                        ? Icons.star_rounded
                        : (fillPercent >= 0.3
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded),
                    color: const Color(0xFFF59E0B),
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Right: Star Distribution Bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final starNum = 5 - i;
                final count = starCounts[starNum] ?? 0;
                final double progress =
                    totalReviews > 0 ? (count / totalReviews) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      Text(
                        '$starNum★',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int starFilter, int count) {
    final isSelected = _selectedStarFilter == starFilter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedStarFilter = starFilter),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (starFilter > 0) ...[
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, Color primaryColor) {
    final customerName = review['customerName']?.toString() ?? 'Customer';
    final ticketId = review['ticketId']?.toString() ?? review['bookingId']?.toString() ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;
    final comment = review['comment']?.toString() ?? '';
    final engineerName = review['engineerName']?.toString() ?? '';
    final deviceBrand = review['deviceBrand']?.toString() ?? '';
    final deviceType = review['deviceType']?.toString() ?? '';
    final createdAt = review['createdAt'] as Timestamp? ?? review['timestamp'] as Timestamp?;

    String dateStr = '';
    if (createdAt != null) {
      dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Ticket ID & Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withValues(alpha: 0.12),
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ticketId.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$ticketId',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Star Score Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rating Stars Row
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B),
                size: 18,
              );
            }),
          ),
          const SizedBox(height: 10),

          // Comment Quote Box
          if (comment.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                '"$comment"',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Footer: Device & Engineer Info
          if (deviceBrand.isNotEmpty || engineerName.isNotEmpty) ...[
            Row(
              children: [
                if (deviceBrand.isNotEmpty || deviceType.isNotEmpty) ...[
                  const Icon(
                    Icons.devices_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$deviceBrand ${deviceType.isNotEmpty ? '- $deviceType' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (engineerName.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Engineer: $engineerName',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF0984E3),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
