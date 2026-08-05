import 'package:url_launcher/url_launcher.dart';

enum RideHailingApp { gojek, grab }

/// Opens the installed ride-hailing app via its official URI scheme
/// (PRD §15: "gunakan deep link resmi jika tersedia"), falling back to its
/// Play Store listing when the app isn't installed. This deliberately only
/// opens the app itself — TK has no partner API access to pre-fill a
/// destination or fetch a real fare, and fabricating that would violate the
/// PRD's "jangan mengambil harga tanpa izin API" rule.
class RideHailingLauncher {
  const RideHailingLauncher();

  static const _appScheme = <RideHailingApp, String>{
    RideHailingApp.gojek: 'gojek://',
    RideHailingApp.grab: 'grab://open',
  };

  static const _playStoreUrl = <RideHailingApp, String>{
    RideHailingApp.gojek:
        'https://play.google.com/store/apps/details?id=com.gojek.app',
    RideHailingApp.grab:
        'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
  };

  Future<bool> open(RideHailingApp app) async {
    final schemeUri = Uri.parse(_appScheme[app]!);
    if (await canLaunchUrl(schemeUri)) {
      return launchUrl(schemeUri, mode: LaunchMode.externalApplication);
    }
    final storeUri = Uri.parse(_playStoreUrl[app]!);
    return launchUrl(storeUri, mode: LaunchMode.externalApplication);
  }
}
