import 'package:flutter/material.dart';

/// Local dismiss state only — deliberately a plain [StatefulWidget], not
/// wired to Riverpod/Supabase, so it can't affect HomeScreen's test
/// stability the way the recurring due-check once did.
class TipCard extends StatefulWidget {
  const TipCard({super.key, required this.tip});

  final String tip;

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.tip, style: TextStyle(color: scheme.onSecondaryContainer)),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: scheme.onSecondaryContainer),
              onPressed: () => setState(() => _dismissed = true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Tutup',
            ),
          ],
        ),
      ),
    );
  }
}
