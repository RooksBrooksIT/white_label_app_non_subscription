import 'package:flutter/material.dart';
import 'package:subscription_rooks_app/services/connectivity_service.dart';
import 'package:subscription_rooks_app/frontend/screens/offline_screen.dart';

/// Global overlay widget that listens to [ConnectivityService].
/// When internet connectivity is lost, it displays the full-screen [OfflineScreen].
/// When connectivity is restored, it automatically hides the overlay and returns
/// the user to the exact screen and state they were previously viewing.
class ConnectivityOverlay extends StatelessWidget {
  final Widget child;

  const ConnectivityOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final isConnected = ConnectivityService.instance.isConnected;

        return Stack(
          fit: StackFit.expand,
          children: [
            // The underlying application view (stays alive, preserves all state)
            child,

            // Full-screen offline overlay when internet is lost
            if (!isConnected)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: const OfflineScreen(),
                ),
              ),
          ],
        );
      },
    );
  }
}
