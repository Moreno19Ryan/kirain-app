import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kirain_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/animated_linear_progress.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/skeleton_box.dart';
import '../categories/data/category.dart';
import '../categories/data/category_icons.dart';
import '../categories/data/category_repository.dart';
import '../tips/data/tip_provider.dart';
import '../tips/presentation/tip_card.dart';
import '../transactions/data/transaction_repository.dart';
import 'data/dashboard_summary.dart';
import 'data/home_widget_sync.dart';
import 'presentation/retroactive_entry_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    // Keeps the Android home-screen widget in step with whatever Home itself
    // just loaded — same freshness Home already has, no extra fetching.
    ref.listen(dashboardSummaryProvider, (_, next) => next.whenData(syncHomeWidget));
    final tip = ref.watch(dailyTipProvider);
    final isNewAccount = ref
        .watch(hasAnyTransactionsProvider)
        .maybeWhen(data: (hasAny) => !hasAny, orElse: () => false);

    return Scaffold(
      appBar: AppBar(title: const Text('KIRAIN')),
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isNewAccount) ...[
                  const RetroactiveEntryBanner(),
                  const SizedBox(height: 16),
                ],
                _HeroCard(summary: summary),
                const SizedBox(height: 16),
                TipCard(tip: tip),
                const SizedBox(height: 20),
                _DetailSection(title: 'Rincian Wajib', summary: summary.wajib),
                const SizedBox(height: 12),
                _DetailSection(title: 'Rincian Keinginan', summary: summary.keinginan),
              ],
            ),
          ),
          loading: () => const _HomeSkeleton(),
          error: (_, _) => ErrorRetryView(
            message: 'Gagal muat data. Coba lagi ya.',
            onRetry: () => ref.invalidate(dashboardSummaryProvider),
          ),
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _HeroSkeleton(),
        SizedBox(height: 16),
        SkeletonBox(height: 64, borderRadius: 16),
        SizedBox(height: 20),
        _SectionSkeleton(),
        SizedBox(height: 12),
        _SectionSkeleton(),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 100, height: 12),
          SizedBox(height: 10),
          SkeletonBox(width: 140, height: 24),
          SizedBox(height: 8),
          SkeletonBox(width: 200, height: 14),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 44)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 44)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SkeletonBox(width: 140, height: 18),
      ),
    );
  }
}

/// The "alis kaget" hero — CLAUDE.md 6.5's signature visual element,
/// combining Wajib + Keinginan into one card instead of the two separate
/// progress cards this screen used to show. The zone ("Zona Aman"/"Zona
/// Kirain") is driven by Wajib alone, per the terminology guide (Wajib
/// fulfillment is what "Progress Cukup" and the zone language are about —
/// overspending on Keinginan doesn't compromise being able to meet needs the
/// same way overspending on Wajib does).
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final mint = kirainColors?.mint ?? theme.colorScheme.primary;
    final coral = kirainColors?.coral ?? theme.colorScheme.secondary;
    final mintStrong = kirainColors?.mintStrong ?? theme.colorScheme.onPrimaryContainer;
    final coralStrong = kirainColors?.coralStrong ?? theme.colorScheme.onSecondaryContainer;
    final textDim = theme.colorScheme.onSurfaceVariant;
    // AppTheme (Fase 2) deliberately maps colorScheme.surface to the `bg`
    // token (not the card `surface` token) so the hero's progress-bar track
    // reads as "inset" against its own lighter card background below.
    final bg = theme.colorScheme.surface;
    final cardSurface = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest;

    final wajib = summary.wajib;
    final hasWajibLimit = wajib.hasLimit;
    final isOver = hasWajibLimit && wajib.ratio >= 1.0;

    final String overline;
    final String title;
    final Color titleColor;
    final String description;
    final Color leftEyebrow;
    final Color rightEyebrow;
    final bool steepEyebrows;

    if (!hasWajibLimit) {
      overline = 'Yuk Mulai Atur';
      title = 'Belum Ada Limit';
      titleColor = textDim;
      description = 'Yuk atur limit budget wajib biar KIRAIN bisa mulai mantau progress kamu.';
      leftEyebrow = mintStrong;
      rightEyebrow = coralStrong;
      steepEyebrows = false;
    } else if (isOver) {
      overline = 'Zona Kamu Sekarang';
      title = 'Zona Kirain';
      titleColor = coralStrong;
      description = 'Bulan ini kebablasan nih, gapapa. Yuk kita rapiin lagi bulan depan 💪';
      leftEyebrow = coralStrong;
      rightEyebrow = coralStrong;
      steepEyebrows = true;
    } else {
      overline = 'Zona Kamu Sekarang';
      title = 'Zona Aman';
      titleColor = mintStrong;
      description = 'Kebutuhan wajib kamu masih terkendali bulan ini.';
      leftEyebrow = mintStrong;
      rightEyebrow = coralStrong;
      steepEyebrows = false;
    }

    final heroTint = isOver ? coral : mint;
    final backgroundEnd = Color.alphaBlend(
      heroTint.withValues(alpha: isOver ? 0.12 : 0.08),
      cardSurface,
    );
    final borderColor = Color.alphaBlend(heroTint.withValues(alpha: 0.3), theme.colorScheme.outline);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardSurface, backgroundEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: _KagetEyebrows(leftColor: leftEyebrow, rightColor: rightEyebrow, steep: steepEyebrows),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: textDim, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(description, style: theme.textTheme.bodySmall?.copyWith(color: textDim)),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HeroLane(
                      label: 'Progress Cukup',
                      group: wajib,
                      trackColor: bg,
                      barColor: isOver ? coral : mint,
                      percentColor: isOver ? coralStrong : textDim,
                      percentBold: isOver,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroLane(
                      label: 'Keinginan',
                      group: summary.keinginan,
                      trackColor: bg,
                      barColor: isOver ? textDim : coral,
                      percentColor: textDim,
                      percentBold: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One lane (Wajib or Keinginan) inside the hero card: label + percentage,
/// mini progress bar, short-format spent/limit, and the period-over-period
/// comparison already computed on [BudgetGroupSummary].
class _HeroLane extends StatelessWidget {
  const _HeroLane({
    required this.label,
    required this.group,
    required this.trackColor,
    required this.barColor,
    required this.percentColor,
    required this.percentBold,
  });

  final String label;
  final BudgetGroupSummary group;
  final Color trackColor;
  final Color barColor;
  final Color percentColor;
  final bool percentBold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLimit = group.hasLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasLimit)
              Text(
                '${(group.ratio * 100).round()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: percentColor,
                  fontWeight: percentBold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (!hasLimit)
          Text('Belum ada limit', style: theme.textTheme.bodySmall)
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedLinearProgress(
              value: group.ratio.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: barColor,
              backgroundColor: trackColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            group.totalLimit > 0
                ? 'Rp ${formatRupiahShort(group.totalSpent)} / Rp ${formatRupiahShort(group.totalLimit)}'
                : 'Rp ${formatRupiahShort(group.totalSpent)} / Rp 0 (limit abis kepake defisit bulan lalu)',
            style: theme.textTheme.bodySmall,
          ),
          _PeriodComparisonLabel(summary: group),
        ],
      ],
    );
  }
}

class _PeriodComparisonLabel extends StatelessWidget {
  const _PeriodComparisonLabel({required this.summary});

  final BudgetGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.percentChangeFromPrevious;
    if (change == null) return const SizedBox.shrink();

    final rounded = change.abs().round();
    final String text;
    final IconData icon;
    if (rounded == 0) {
      text = 'Sama kayak bulan lalu';
      icon = Icons.horizontal_rule;
    } else if (change > 0) {
      text = 'Naik $rounded% dari bulan lalu';
      icon = Icons.arrow_upward;
    } else {
      text = 'Turun $rounded% dari bulan lalu';
      icon = Icons.arrow_downward;
    }

    final color = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-type breakdown, collapsed by default — CLAUDE.md's "Transparansi
/// perhitungan: breakdown yang bisa di-expand/tap, bukan black box". Hidden
/// entirely once auto-collapse (see dashboard_summary.dart) leaves nothing
/// to show for that type.
class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.summary});

  final String title;
  final BudgetGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.items.isEmpty) return const SizedBox.shrink();

    final rollover = summary.totalRollover;
    final subtitle = rollover == 0
        ? null
        : rollover > 0
        ? 'Termasuk bawaan bulan lalu: +Rp ${formatRupiahShort(rollover)}'
        : 'Termasuk bawaan defisit bulan lalu: -Rp ${formatRupiahShort(rollover.abs())}';

    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        children: summary.items.map((item) => _CategoryTile(item: item)).toList(),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.item});

  final CategorySpend item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = item.category.budgetLimit;
    final hasLimit = limit != null && limit > 0;
    final over = hasLimit && item.spent > item.effectiveLimit;
    final ratio = hasLimit && item.effectiveLimit > 0 ? item.spent / item.effectiveLimit : 0.0;
    final isWarning = !over && hasLimit && ratio >= item.category.alertThresholdPct / 100;
    const warningColor = Colors.orange;

    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final iconColor = categoryIconColor(
      category: item.category,
      mintStrong: kirainColors?.mintStrong ?? theme.colorScheme.onPrimaryContainer,
      coralStrong: kirainColors?.coralStrong ?? theme.colorScheme.onSecondaryContainer,
      neutral: theme.colorScheme.onSurfaceVariant,
    );

    return ListTile(
      leading: Icon(categoryIcon(item.category), color: iconColor),
      title: Text(item.category.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !hasLimit
                ? 'Rp ${formatRupiah(item.spent)} · belum ada limit'
                : 'Rp ${formatRupiah(item.spent)} dari Rp ${formatRupiah(item.effectiveLimit)}',
            style: over
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : isWarning
                ? const TextStyle(color: warningColor)
                : null,
          ),
          if (isWarning)
            const Text(
              'Zona Waspada — udah mendekati limit nih',
              style: TextStyle(color: warningColor, fontSize: 12),
            ),
          if (item.rollover != 0)
            Text(
              item.rollover > 0
                  ? 'Bawaan bulan lalu: +Rp ${formatRupiah(item.rollover)}'
                  : 'Bawaan defisit bulan lalu: -Rp ${formatRupiah(item.rollover.abs())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => _showEditLimitDialog(context, ref, item.category),
    );
  }
}

/// The two asymmetric "raised eyebrow" arcs that are KIRAIN's signature
/// visual mark (CLAUDE.md 6.5) — reinterpreted from the reference SVG paths
/// as a CustomPainter rather than ported directly. `steep` mirrors the
/// reference's Zona Kirain variant: same arcs, pulled tighter for a more
/// urgent "kaget" expression.
class _KagetEyebrows extends StatelessWidget {
  const _KagetEyebrows({required this.leftColor, required this.rightColor, required this.steep});

  final Color leftColor;
  final Color rightColor;
  final bool steep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 43,
      child: CustomPaint(
        painter: _KagetEyebrowsPainter(leftColor: leftColor, rightColor: rightColor, steep: steep),
      ),
    );
  }
}

class _KagetEyebrowsPainter extends CustomPainter {
  _KagetEyebrowsPainter({required this.leftColor, required this.rightColor, required this.steep});

  final Color leftColor;
  final Color rightColor;
  final bool steep;

  /// Reference viewBox from the mockup's SVG — canvas is scaled to fit
  /// whatever size the widget's actually given.
  static const _refWidth = 120.0;
  static const _refHeight = 54.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _refWidth, size.height / _refHeight);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final left = Path();
    final right = Path();
    if (steep) {
      left
        ..moveTo(6, 44)
        ..quadraticBezierTo(30, -2, 54, 26);
      right
        ..moveTo(66, 26)
        ..quadraticBezierTo(90, -2, 114, 44);
    } else {
      left
        ..moveTo(6, 40)
        ..quadraticBezierTo(30, 2, 54, 30);
      right
        ..moveTo(66, 30)
        ..quadraticBezierTo(90, 2, 114, 40);
    }

    canvas.drawPath(left, paint..color = leftColor);
    canvas.drawPath(right, paint..color = rightColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KagetEyebrowsPainter oldDelegate) {
    return leftColor != oldDelegate.leftColor ||
        rightColor != oldDelegate.rightColor ||
        steep != oldDelegate.steep;
  }
}

Future<void> _showEditLimitDialog(BuildContext context, WidgetRef ref, Category category) async {
  final controller = TextEditingController(
    text: category.budgetLimit == null ? '' : category.budgetLimit!.toStringAsFixed(0),
  );

  final result = await showDialog<num>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Limit ${category.name}'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Limit per siklus (Rp)'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final value = num.tryParse(controller.text.trim());
            Navigator.pop(dialogContext, value ?? 0);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );

  if (result == null) return;

  await ref.read(categoryRepositoryProvider).updateBudgetLimit(category.id, result);
  ref.invalidate(categoriesProvider);
  ref.invalidate(dashboardSummaryProvider);
}
