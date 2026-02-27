import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // We can use a TweenAnimationBuilder for entrance, avoiding complex controllers

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(launchUri)) {
      debugPrint("Could not launch $launchUri");
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(launchUri)) {
      debugPrint("Could not launch $launchUri");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StaggeredEntry(
                delay: 0,
                child: Text(
                  "Support",
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _StaggeredEntry(
                delay: 100,
                child: Text(
                  "How can we help you today?",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              _StaggeredEntry(
                delay: 200,
                child: _SupportCard(
                  icon: Icons.phone_in_talk_outlined,
                  title: "Call Us",
                  subtitle: "Speak directly to our support team.",
                  actionText: "8124138439",
                  color: Colors.blue.shade600,
                  onTap: () => _makePhoneCall("8124138439"),
                ),
              ),
              const SizedBox(height: 20),

              _StaggeredEntry(
                delay: 300,
                child: _SupportCard(
                  icon: Icons.email_outlined,
                  title: "Email Us",
                  subtitle: "Send us a detailed query.",
                  actionText: "abishek.rooks@gmail.com",
                  color: Colors.deepPurple.shade500,
                  onTap: () => _sendEmail("abishek.rooks@gmail.com"),
                ),
              ),

              const SizedBox(height: 60),
              _StaggeredEntry(
                delay: 400,
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.headset_mic_outlined,
                        size: 40,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Our team is available\nMon-Fri • 9am - 6pm",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
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

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;
  final Color color;
  final VoidCallback onTap;

  const _SupportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            actionText,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  final Widget child;
  final int delay;

  const _StaggeredEntry({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // We delay the start by clamping or using value logic?
        // Simple Tween doesn't delay.
        // We can use a FutureBuilder or just let it play.
        // But for "Staggered", we need delay.
        // Let's use a delayed FutureBuilder triggering a boolean?
        // Or simpler: Just animate opacity/slide, but faster?
        // No, standard flutter stagger:
        // Use a stateful widget that starts animation after delay.
        return _DelayedAnimator(delay: delay, child: child!);
      },
      child: child,
    );
  }
}

class _DelayedAnimator extends StatefulWidget {
  final int delay;
  final Widget child;
  const _DelayedAnimator({required this.delay, required this.child});

  @override
  State<_DelayedAnimator> createState() => _DelayedAnimatorState();
}

class _DelayedAnimatorState extends State<_DelayedAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _slide.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
