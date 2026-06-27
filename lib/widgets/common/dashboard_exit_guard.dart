import 'package:flutter/material.dart';

class DashboardExitGuard extends StatefulWidget {
  final int currentIndex;
  final VoidCallback onGoHome;
  final Widget child;

  const DashboardExitGuard({
    super.key,
    required this.currentIndex,
    required this.onGoHome,
    required this.child,
  });

  @override
  State<DashboardExitGuard> createState() => _DashboardExitGuardState();
}

class _DashboardExitGuardState extends State<DashboardExitGuard> {
  DateTime? _lastBackPressedAt;

  Future<bool> _handleBack() async {
    if (widget.currentIndex != 0) {
      widget.onGoHome();
      return false;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null && now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

    if (shouldExit) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return true;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit app'),
          duration: Duration(seconds: 2),
        ),
      );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await _handleBack();
        if (shouldExit && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: widget.child,
    );
  }
}
