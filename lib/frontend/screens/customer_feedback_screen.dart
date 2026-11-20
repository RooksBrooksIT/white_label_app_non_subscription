import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:subscription_rooks_app/services/firestore_service.dart';
import 'package:subscription_rooks_app/services/notification_service.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
import 'package:subscription_rooks_app/utils/responsive_wrapper.dart';

class CustomerFeedbackScreen extends StatefulWidget {
  final String ticketId;
  final String? customerId;
  final String? customerName;
  final String? deviceBrand;
  final String? deviceType;
  final String? engineerName;
  final DateTime? completedDate;

  const CustomerFeedbackScreen({
    super.key,
    required this.ticketId,
    this.customerId,
    this.customerName,
    this.deviceBrand,
    this.deviceType,
    this.engineerName,
    this.completedDate,
  });

  @override
  State<CustomerFeedbackScreen> createState() => _CustomerFeedbackScreenState();
}

class _CustomerFeedbackScreenState extends State<CustomerFeedbackScreen> {
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isAlreadySubmitted = false;

  // Resolved ticket metadata
  String _customerName = '';
  String _customerId = '';
  String _deviceBrand = '';
  String _deviceType = '';
  String _engineerName = '';
  DateTime? _completedDate;
  double _existingRating = 0.0;
  String _existingFeedback = '';
  DateTime? _feedbackSubmittedAt;

  static const List<String> _ratingLabels = [
    'Tap a star to rate',
    'Poor',
    'Fair',
    'Good',
    'Very Good',
    'Excellent',
  ];

  static const List<Color> _ratingColors = [
    Color(0xFF94A3B8),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
  ];

  @override
  void initState() {
    super.initState();
    _customerName = widget.customerName ?? '';
    _customerId = widget.customerId ?? '';
    _deviceBrand = widget.deviceBrand ?? '';
    _deviceType = widget.deviceType ?? '';
    _engineerName = widget.engineerName ?? '';
    _completedDate = widget.completedDate;

    _feedbackController.addListener(() {
      setState(() {});
    });

    _loadTicketDetails();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketDetails() async {
    try {
      final ticketId = widget.ticketId.trim();
      if (ticketId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      DocumentSnapshot? doc;
      try {
        doc = await FirestoreService.instance
            .collection('Admin_ticket_entry')
            .doc(ticketId)
            .get();
      } catch (_) {}

      if (doc == null || !doc.exists) {
        try {
          doc = await FirestoreService.instance
              .collection('Raised_tickets')
              .doc(ticketId)
              .get();
        } catch (_) {}
      }

      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};

        final existingRatingVal =
            (data['customerRating'] ?? data['rating'] as num?)?.toDouble();
        final existingCommentVal =
            (data['customerFeedback'] ??
                    data['ratingComment'] ??
                    data['comment'] ??
                    '')
                .toString()
                .trim();
        final feedbackStatusVal = (data['feedbackStatus'] ?? '')
            .toString()
            .trim();

        if (existingRatingVal != null && existingRatingVal > 0) {
          _isAlreadySubmitted = true;
          _existingRating = existingRatingVal;
          _existingFeedback = existingCommentVal;
          if (data['feedbackSubmittedAt'] is Timestamp) {
            _feedbackSubmittedAt = (data['feedbackSubmittedAt'] as Timestamp)
                .toDate();
          } else if (data['ratedAt'] is Timestamp) {
            _feedbackSubmittedAt = (data['ratedAt'] as Timestamp).toDate();
          }
        } else if (feedbackStatusVal.toLowerCase() == 'submitted') {
          _isAlreadySubmitted = true;
          _existingRating = existingRatingVal ?? 5.0;
          _existingFeedback = existingCommentVal;
        }

        if (_customerName.isEmpty) {
          _customerName = (data['customerName'] ?? '').toString();
        }
        if (_customerId.isEmpty) {
          _customerId =
              (data['id'] ?? data['customerId'] ?? data['customerid'] ?? '')
                  .toString();
        }
        if (_deviceBrand.isEmpty) {
          _deviceBrand = (data['deviceBrand'] ?? '').toString();
        }
        if (_deviceType.isEmpty) {
          _deviceType = (data['deviceType'] ?? data['DeviceName'] ?? '')
              .toString();
        }
        if (_engineerName.isEmpty) {
          _engineerName =
              (data['assignedEngineer'] ?? data['assignedEmployee'] ?? '')
                  .toString();
        }
        if (_completedDate == null) {
          if (data['completedAt'] is Timestamp) {
            _completedDate = (data['completedAt'] as Timestamp).toDate();
          } else if (data['deliveredAt'] is Timestamp) {
            _completedDate = (data['deliveredAt'] as Timestamp).toDate();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading ticket details in feedback screen: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isFormValid {
    return _selectedRating >= 1 &&
        _selectedRating <= 5 &&
        _feedbackController.text.trim().isNotEmpty;
  }

  Future<void> _submitFeedback() async {
    if (!_isFormValid || _isSubmitting || _isAlreadySubmitted) return;

    setState(() => _isSubmitting = true);

    final cleanTicketId = widget.ticketId.trim();
    final cleanFeedback = _feedbackController.text.trim();
    final ratingDocRef = FirestoreService.instance.collection('ratings').doc();

    try {
      // 1. Concurrency Check: verify ticket is not already rated
      try {
        final checkDoc = await FirestoreService.instance
            .collection('Admin_ticket_entry')
            .doc(cleanTicketId)
            .get();
        if (checkDoc.exists) {
          final cData = checkDoc.data() ?? {};
          if (cData['feedbackStatus'] == 'Submitted' ||
              cData['customerRating'] != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Feedback has already been submitted for this ticket.',
                  ),
                  backgroundColor: Color(0xFFF59E0B),
                ),
              );
              setState(() {
                _isAlreadySubmitted = true;
                _isSubmitting = false;
                _existingRating =
                    (cData['customerRating'] ?? cData['rating'] as num?)
                        ?.toDouble() ??
                    5.0;
                _existingFeedback =
                    (cData['customerFeedback'] ?? cData['comment'] ?? '')
                        .toString();
              });
              return;
            }
          }
        }
      } catch (_) {}

      // 2. Write to ratings collection under tenant
      final ratingPayload = {
        'id': ratingDocRef.id,
        'ratingId': ratingDocRef.id,
        'ticketId': cleanTicketId,
        'bookingId': cleanTicketId,
        'customerName': _customerName,
        'customerId': _customerId,
        'engineerName': _engineerName,
        'rating': _selectedRating,
        'comment': cleanFeedback,
        'feedback': cleanFeedback,
        'deviceBrand': _deviceBrand,
        'deviceType': _deviceType,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await ratingDocRef.set(ratingPayload);

      // 3. Atomically update both Admin_ticket_entry and Raised_tickets
      final ticketUpdate = {
        'customerRating': _selectedRating,
        'rating': _selectedRating,
        'customerFeedback': cleanFeedback,
        'comment': cleanFeedback,
        'ratingComment': cleanFeedback,
        'feedbackStatus': 'Submitted',
        'feedbackSubmittedAt': FieldValue.serverTimestamp(),
        'ratedAt': FieldValue.serverTimestamp(),
        'feedbackSubmittedBy': _customerName,
      };

      try {
        await FirestoreService.instance
            .collection('Admin_ticket_entry')
            .doc(cleanTicketId)
            .set(ticketUpdate, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating Admin_ticket_entry with feedback: $e');
      }

      try {
        await FirestoreService.instance
            .collection('Raised_tickets')
            .doc(cleanTicketId)
            .set(ticketUpdate, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating Raised_tickets with feedback: $e');
      }

      // 4. Mark completion feedback notification as seen in notifications collection
      try {
        final notifSnap = await FirestoreService.instance
            .collection('notifications')
            .where('bookingId', isEqualTo: cleanTicketId)
            .get();

        for (final doc in notifSnap.docs) {
          final nData = doc.data() as Map<String, dynamic>? ?? {};
          if (nData['type'] == 'ticket_completed_feedback' ||
              nData['notificationType'] == 'ticket_completed_feedback') {
            await doc.reference.update({'seen': true});
          }
        }
      } catch (_) {}

      // 5. Notify Admin of customer rating submission
      try {
        await NotificationService.sendNotificationToFirestore(
          audience: 'admin',
          title: 'New Customer Rating Received',
          body:
              '$_customerName submitted feedback for ticket #$cleanTicketId: $_selectedRating★ ("$cleanFeedback")',
          type: 'customer_rating',
          bookingId: cleanTicketId,
          customerName: _customerName,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isAlreadySubmitted = true;
          _existingRating = _selectedRating.toDouble();
          _existingFeedback = cleanFeedback;
          _feedbackSubmittedAt = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thank you! Your feedback has been submitted successfully.',
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Allow user a moment to see confirmation before popping
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error submitting customer feedback: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Service Feedback & Rating',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: ResponsiveWrapper(
        maxWidth: 640,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ticket Details Summary Card
                    _buildTicketSummaryCard(primaryColor),
                    const SizedBox(height: 20),

                    // Rating Form or Read-Only Submitted Feedback
                    if (_isAlreadySubmitted)
                      _buildSubmittedFeedbackCard(primaryColor)
                    else
                      _buildRatingForm(primaryColor),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTicketSummaryCard(Color primaryColor) {
    final completedFormatted = _completedDate != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(_completedDate!)
        : 'Recently Completed';

    final deviceText = [
      if (_deviceBrand.isNotEmpty) _deviceBrand,
      if (_deviceType.isNotEmpty) _deviceType,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${widget.ticketId}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Device & Engineer info
          _buildSummaryRow(
            icon: Icons.devices_rounded,
            label: 'Device',
            value: deviceText.isNotEmpty ? deviceText : 'Service Device',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.person_rounded,
            label: 'Assigned Engineer',
            value: _engineerName.isNotEmpty ? _engineerName : 'Technician',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.event_available_rounded,
            label: 'Completion Date',
            value: completedFormatted,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingForm(Color primaryColor) {
    final currentColor = _ratingColors[_selectedRating];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Rate Your Service Experience',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your rating and feedback are mandatory to complete this service ticket.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),

                // 5 Interactive Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    final isSelected = starVal <= _selectedRating;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRating = starVal;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedScale(
                          scale: isSelected ? 1.18 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 40,
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),

                // Selected Star Label
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: currentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _ratingLabels[_selectedRating],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: currentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feedback Description Field
          Row(
            children: [
              Text(
                'Feedback Description',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _feedbackController,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Please share your experience with our service...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
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
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          if (_feedbackController.text.trim().isEmpty &&
              _selectedRating > 0) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Feedback description is required.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isFormValid && !_isSubmitting
                  ? _submitFeedback
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submit Feedback',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedFeedbackCard(Color primaryColor) {
    final submittedFormatted = _feedbackSubmittedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(_feedbackSubmittedAt!)
        : 'Recently Submitted';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback Submitted',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Thank you for rating our service! Your feedback is recorded.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Star Display
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < _existingRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 24,
                  );
                }),
              ),
              const SizedBox(width: 10),
              Text(
                '${_existingRating.toStringAsFixed(1)} / 5.0',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Submitted Comment
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Comments',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _existingFeedback.isNotEmpty
                      ? _existingFeedback
                      : 'No additional comments provided.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                'Submitted on $submittedFormatted',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
