import 'package:home_widget/home_widget.dart';

import '../../../core/utils/format.dart';
import 'dashboard_summary.dart';

/// Must match the `<receiver>` class name registered in
/// AndroidManifest.xml — see KirainWidgetProvider.kt.
const androidHomeWidgetName = 'KirainWidgetProvider';

/// Pushes the latest "sisa budget" summary to the Android home-screen widget
/// and asks it to redraw. Best-effort: a device with no widget pinned just
/// gets data sitting unused, and any platform-channel hiccup here should
/// never surface as an error in the screen that triggered it (this runs
/// opportunistically off the back of Home's own data loads).
Future<void> syncHomeWidget(DashboardSummary summary) async {
  try {
    await HomeWidget.saveWidgetData<String>(
      'wajib_remaining',
      _remainingLabel(summary.wajib),
    );
    await HomeWidget.saveWidgetData<String>(
      'keinginan_remaining',
      _remainingLabel(summary.keinginan),
    );
    await HomeWidget.updateWidget(androidName: androidHomeWidgetName);
  } catch (_) {
    // Nice-to-have sync — never let it bubble up as an app-facing error.
  }
}

/// Same "Rp X dari Y" framing Home itself uses, condensed into one line for
/// the widget's tighter layout.
String _remainingLabel(BudgetGroupSummary group) {
  if (!group.hasLimit) return 'Belum ada limit';

  final remaining = group.totalLimit - group.totalSpent;
  if (remaining < 0) {
    return 'Zona Kirain, lewat Rp ${formatRupiah(remaining.abs())}';
  }
  return 'Rp ${formatRupiah(remaining)} sisa';
}
