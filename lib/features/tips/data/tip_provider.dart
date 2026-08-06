import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'financial_tips.dart';

/// Picked once per provider lifetime, i.e. once per app session — Home
/// stays mounted (hidden, not disposed) inside the bottom-nav's
/// IndexedStack, so this doesn't re-roll on every tab switch.
final dailyTipProvider = Provider<String>((ref) {
  return financialTips[Random().nextInt(financialTips.length)];
});
