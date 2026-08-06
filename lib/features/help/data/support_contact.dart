import 'package:url_launcher/url_launcher.dart';

/// Support channels per CLAUDE.md: WA Bisnis + email. Kept in one place
/// since both the FAQ screen and (later) the ToS/Privacy screens point
/// here.
class SupportContact {
  const SupportContact._();

  static const _waNumber = '6285542201902';
  static const email = 'morenoryandika@gmail.com';

  static Future<bool> openWhatsApp() {
    return launchUrl(
      Uri.parse('https://wa.me/$_waNumber'),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> openEmail() {
    return launchUrl(
      Uri(scheme: 'mailto', path: email, query: 'subject=Bantuan KIRAIN'),
    );
  }
}
