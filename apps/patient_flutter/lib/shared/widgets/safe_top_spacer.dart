import 'package:flutter/material.dart';

/// Status-bar aware top spacing for screens rendered outside a Scaffold
/// AppBar (branch roots, custom headers).
///
/// This device enforces edge-to-edge rendering, so a fixed top offset is not
/// enough: the inset (status bar / display cutout) must be measured at
/// runtime. [extra] adds a comfortable visual margin below the system inset.
class SafeTopSpacer extends StatelessWidget {
  const SafeTopSpacer({super.key, this.extra = 16});

  final double extra;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.paddingOf(context).top + extra);
  }
}
