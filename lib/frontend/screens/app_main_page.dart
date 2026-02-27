import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_geo_location_screen.dart';
import 'package:subscription_rooks_app/frontend/screens/admin_login_page.dart';
import 'package:subscription_rooks_app/frontend/screens/customer_login_pages.dart';
import 'package:subscription_rooks_app/frontend/screens/engineer_login_page.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';
// Import your customer page here

class AppMainPage extends StatelessWidget {
  const AppMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isLargeScreen = width > 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Subtle background pattern - Simplified
          _buildBackgroundPattern(context),

          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 60 : 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header Section
                  _buildHeaderSection(context, isLargeScreen),

                  SizedBox(height: isLargeScreen ? 60 : 40),

                  // Login Cards
                  _buildLoginCardsSection(context, isLargeScreen, width),

                  SizedBox(height: isLargeScreen ? 50 : 40),

                  // About Us Section
                  _buildAboutSection(context, isLargeScreen),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPattern(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100]!.withOpacity(0.5),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -40,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[50]!.withOpacity(0.5),
            ),
          ),
        ),
        Positioned(
          top: 150,
          left: -20,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.02),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, bool isLargeScreen) {
    final logoUrl = ThemeService.instance.logoUrl;
    return Column(
      children: [
        // Logo
        Container(
          padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: logoUrl != null
              ? Image.network(
                  logoUrl,
                  width: isLargeScreen ? 90 : 65,
                  height: isLargeScreen ? 90 : 65,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.business_rounded,
                    size: isLargeScreen ? 90 : 65,
                    color: Colors.black,
                  ),
                )
              : Image.asset(
                  'assets/images/logo.png',
                  width: isLargeScreen ? 90 : 65,
                  height: isLargeScreen ? 90 : 65,
                  fit: BoxFit.contain,
                ),
        ),
        SizedBox(height: isLargeScreen ? 30 : 25),

        // Title
        Text(
          ThemeService.instance.appName,
          style: TextStyle(
            fontSize: isLargeScreen ? 38 : 30,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),

        // Subtitle
        Text(
          "Select your portal to continue",
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCardsSection(
    BuildContext context,
    bool isLargeScreen,
    double width,
  ) {
    if (isLargeScreen) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProfessionalCard(
            context: context,
            title: "Customer",
            subtitle: "Access services & requests",
            icon: Icons.person_outline_rounded,
            backgroundColor: Colors.white,
            textColor: Colors.black,
            borderColor: Colors.grey[300],
            cardWidth: width * 0.22,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => CustomerTypePage()));
            },
          ),
          SizedBox(width: 20),
          _buildProfessionalCard(
            context: context,
            title: "Admin",
            subtitle: "Manage platform & users",
            icon: Icons.admin_panel_settings_outlined,
            backgroundColor: Colors.black,
            textColor: Colors.white,
            cardWidth: width * 0.22,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AdminGeoLocationScreen(engineerId: '', engineerName: ''),
                ),
              );
            },
          ),
          SizedBox(width: 20),
          _buildProfessionalCard(
            context: context,
            title: "Engineer",
            subtitle: "Handle service tasks",
            icon: Icons.engineering_outlined,
            backgroundColor: Colors.grey[100]!,
            textColor: Colors.black,
            cardWidth: width * 0.22,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => Engineerlogin()));
            },
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildProfessionalCard(
            context: context,
            title: "Customer",
            subtitle: "Access services and requests",
            icon: Icons.person_outline_rounded,
            backgroundColor: Colors.white,
            textColor: Colors.black,
            borderColor: Colors.grey[300],
            cardWidth: double.infinity,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => CustomerTypePage()));
            },
          ),
          SizedBox(height: 16),
          _buildProfessionalCard(
            context: context,
            title: "Admin",
            subtitle: "Manage platform and users",
            icon: Icons.admin_panel_settings_outlined,
            backgroundColor: Colors.black,
            textColor: Colors.white,
            cardWidth: double.infinity,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => AdminLogin()));
            },
          ),
          SizedBox(height: 16),
          _buildProfessionalCard(
            context: context,
            title: "Engineer",
            subtitle: "Handle service tasks",
            icon: Icons.engineering_outlined,
            backgroundColor: Colors.grey[100]!,
            textColor: Colors.black,
            cardWidth: double.infinity,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => Engineerlogin()));
            },
          ),
        ],
      );
    }
  }

  Widget _buildProfessionalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    required double cardWidth,
    required VoidCallback onTap,
  }) {
    return Container(
      width: cardWidth,
      height: 120,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
        boxShadow: backgroundColor == Colors.black
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: textColor, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.7),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textColor.withOpacity(0.4),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, bool isLargeScreen) {
    return Column(
      children: [
        Text(
          "v 1.2.0",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _showProfessionalAboutDialog(context),
          icon: Icon(Icons.info_outline_rounded, size: 18),
          label: Text("About Platform"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: BorderSide(color: Colors.grey[300]!, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showProfessionalAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(maxWidth: 450),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business_center_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ThemeService.instance.appName,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "Enterprise Platform",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "A comprehensive white-label solution designed to streamline service management. We connect teams and customers with professional tools and seamless workflows.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildFeatureChip("Secure"),
                    _buildFeatureChip("Scalable"),
                    _buildFeatureChip("Modern"),
                  ],
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
