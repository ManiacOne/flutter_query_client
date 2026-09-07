import 'package:flutter/material.dart';

import 'app_navigation.dart';

/// Renders the currently-selected drawer section. Each section is a full
/// `Scaffold` that embeds the shared [AppDrawer], so navigation is driven by
/// [selectedSection] rather than a bottom navigation bar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedSection,
      builder: (context, index, _) => appSections[index].builder(context),
    );
  }
}
