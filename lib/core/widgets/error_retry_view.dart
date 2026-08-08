import 'package:flutter/material.dart';

/// Shared error state for failed [FutureProvider]/[AsyncValue] loads — a
/// message plus a retry button, per CLAUDE.md's "Error state jelas +
/// actionable (tombol retry...)" requirement. Centered, so it drops straight
/// into any screen's `error:` callback.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
