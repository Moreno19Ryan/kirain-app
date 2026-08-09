import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Keeps the whole test suite offline and deterministic — without this,
/// building `AppTheme` would fire real network requests to fetch Sora/Inter
/// on first use. Per google_fonts' own recommended test setup.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
