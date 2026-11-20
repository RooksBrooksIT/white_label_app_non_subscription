import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:subscription_rooks_app/services/theme_service.dart';

class UpdateDialog extends StatelessWidget {
  final String title;
  final String message;
  final String installedVersion;
  final int installedBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool isMandatory;
  final String packageName;
  final String playStoreUrl;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.installedVersion,
    required this.installedBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.isMandatory,
    required this.packageName,
    required this.playStoreUrl,
    this.onDismiss,
  });

  Future<void> _launchAppStore() async {
    final pkg = packageName.isNotEmpty ? packageName : 'com.rooks.subscription';
    final marketUri = Uri.parse('market://details?id=$pkg');
    final webUri = playStoreUrl.isNotEmpty
        ? Uri.parse(playStoreUrl)
        : Uri.parse('https://play.google.com/store/apps/details?id=$pkg');

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      debugPrint('[UpdateDialog] Error launching store: $e');
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.instance.primaryColor;

    return PopScope(
      canPop: !isMandatory,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMandatory
                      ? Icons.system_security_update_rounded
                      : Icons.rocket_launch_rounded,
                  color: primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title.isNotEmpty ? title : 'New Update Available!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),

              if (isMandatory) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Text(
                    'Mandatory Update',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Version Comparison Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Installed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          installedBuildNumber > 0
                              ? 'v$installedVersion ($installedBuildNumber)'
                              : 'v$installedVersion',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                    Column(
                      children: [
                        const Text(
                          'Latest Available',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latestBuildNumber > 0
                              ? 'v$latestVersion ($latestBuildNumber)'
                              : 'v$latestVersion',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Message / Update Description
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message.isNotEmpty
                        ? message
                        : 'A new version of ServNex is available. Update your application to access the latest improvements, features and bug fixes.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Buttons
              Row(
                children: [
                  if (!isMandatory) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _launchAppStore();
                        if (!isMandatory) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
