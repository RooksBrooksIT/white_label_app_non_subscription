import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: primaryColor,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        color: const Color(0xFFF8F9FA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get in Touch',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If you need support or have questions, reach out to us using the details below.',
              style: TextStyle(
                fontSize: 15,
                color: textColor.withOpacity(0.75),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactRow(
                      icon: Icons.location_on_rounded,
                      label: 'Address',
                      value:
                          'No. 17, Jawahar Street, Ramavarmapuram, Nagercoil – 629001',
                    ),
                    const SizedBox(height: 18),
                    _buildContactRow(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: 'support@rookstechnologies.com',
                    ),
                    const SizedBox(height: 18),
                    _buildContactRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: '+91 7358677670',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Support Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Monday to Saturday, 9:00 AM to 6:00 PM',
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF2C6BED), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 14, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
