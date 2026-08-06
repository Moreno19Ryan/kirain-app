import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/features/auth/data/auth_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('otpErrorMessage', () {
    test('gives accurate copy for the email rate-limit error', () {
      const error = AuthException(
        'Email rate limit exceeded',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      );

      expect(otpErrorMessage(error), contains('dibatasin'));
    });

    test('also recognizes the rate limit by code alone', () {
      const error = AuthException(
        'Email rate limit exceeded',
        code: 'over_email_send_rate_limit',
      );

      expect(otpErrorMessage(error), contains('dibatasin'));
    });

    test('falls back to the generic connectivity message otherwise', () {
      const error = AuthException('Something else went wrong', statusCode: '500');

      expect(otpErrorMessage(error), contains('cek internet kamu'));
      expect(otpErrorMessage(Exception('unrelated')), contains('cek internet kamu'));
    });
  });
}
