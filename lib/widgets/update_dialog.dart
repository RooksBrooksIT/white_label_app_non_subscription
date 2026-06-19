import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool forceUpdate;
  final String packageName;

  const UpdateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.forceUpdate,
    required this.packageName,
  });

  Future<void> _launchAppStore() async {
    final url = Uri.parse('market://details?id=$packageName');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final webUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ElevatedButton(
            onPressed: () {
              _launchAppStore();
              if (!forceUpdate) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
