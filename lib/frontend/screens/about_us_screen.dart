import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
        backgroundColor: primaryColor,
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF8F9FA),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to ServNex.',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ServNex is a smart IT service platform designed to make service booking, tracking, and management simple and efficient. Our goal is to provide users with a seamless experience when accessing IT-related services.',
              style: TextStyle(
                fontSize: 15,
                color: textColor.withOpacity(0.78),
                height: 1.8,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'With ServNex, users can easily:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 14),
            _buildBulletPoint('Book IT services'),
            const SizedBox(height: 10),
            _buildBulletPoint('Track service progress in real time'),
            const SizedBox(height: 10),
            _buildBulletPoint('Manage service requests efficiently'),
            const SizedBox(height: 22),
            Text(
              'We focus on delivering a smooth, reliable, and user-friendly experience for both individuals and businesses. Our mission is to simplify IT service management through innovation, transparency, and technology.',
              style: TextStyle(
                fontSize: 15,
                color: textColor.withOpacity(0.78),
                height: 1.8,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'COMPANY DETAILS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 14),
            _buildCompanyDetail('Business Name', 'ServNex'),
            const SizedBox(height: 10),
            _buildCompanyDetail(
              'Address',
              'No:17, Jawahar Street, Ramavarmapuram, Nagercoil - 629001',
            ),
            const SizedBox(height: 10),
            _buildCompanyDetail('Email', 'support@rookstechnologies.com'),
            const SizedBox(height: 10),
            _buildCompanyDetail('Phone', '+91 7358677670'),
            const SizedBox(height: 24),
            Text(
              'Thank you for choosing ServNex.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF2C6BED),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.75)),
        ),
      ],
    );
  }

  Widget _buildCompanyDetail(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, height: 1.7)),
      ],
    );
  }
}
