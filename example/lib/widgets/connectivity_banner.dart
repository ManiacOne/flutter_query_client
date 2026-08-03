import 'package:flutter/material.dart';

/// Global connectivity signal fed by [QueryClientProvider.onConnectivityChanged].
///
/// Wired once in `main.dart`; [ConnectivityBanner] listens to this to show a
/// live "offline" indicator anywhere in the app.
final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

/// Wraps [child] with a persistent banner that appears whenever the device
/// loses internet connectivity, driven by flutter_query_client's native
/// connectivity signal.
class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isOnlineNotifier,
      builder: (context, isOnline, _) {
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isOnline
                  ? const SizedBox.shrink()
                  : Material(
                      color: Colors.red.shade700,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'No internet connection',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
