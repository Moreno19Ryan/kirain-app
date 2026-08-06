import 'package:supabase_flutter/supabase_flutter.dart';

const _rateLimitCode = 'over_email_send_rate_limit';

/// Supabase's default (unconfigured) email service has a very low send
/// rate limit — a few requests in a row during testing is enough to hit
/// it. The generic "cek internet kamu" message is actively misleading in
/// that case, so this gets its own, accurate copy.
String otpErrorMessage(Object error) {
  if (error is AuthException && (error.statusCode == '429' || error.code == _rateLimitCode)) {
    return 'Kode OTP-nya lagi dibatasin nih soalnya kekirim kebanyakan '
        'beruntun. Tunggu beberapa menit ya, terus coba lagi 🙏';
  }

  return 'Yah, kode gagal dikirim. Coba cek internet kamu, atau tunggu bentar ya 🔌';
}
