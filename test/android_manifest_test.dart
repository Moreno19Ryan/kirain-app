import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidManifest.xml (release network access)', () {
    test('the main (release) manifest declares INTERNET', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      // Debug/profile builds silently get INTERNET from Flutter's own
      // per-variant manifests (for the VM service/hot reload), which is
      // exactly how this went missing from the main manifest unnoticed —
      // only `main`'s manifest ships in a release build, and KIRAIN talks
      // to Supabase from first launch. This is a source-level regression
      // guard, not proof a real release APK can make a network request —
      // it can't run an actual build/device check without Android
      // tooling. See ANDROID-001's PR description for the manual
      // verification step this still needs.
      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason:
            'android/app/src/main/AndroidManifest.xml is missing the INTERNET '
            'permission — a release build would have zero network access '
            '(not just sync, Supabase auth too). debug/profile manifests '
            "grant it for free via Flutter's own tooling, which is why this "
            "regressing wouldn't be caught by `flutter run` during normal "
            'development.',
      );
    });
  });
}
