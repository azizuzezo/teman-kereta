import 'package:device_info_plus/device_info_plus.dart';

/// A best-effort stable device identifier, used only to tie the premium
/// feature's one-time free trial to a physical device rather than an
/// account (see `claim_trial()` in
/// `20260806140000_premium_subscriptions.sql`). This is Android's
/// `Settings.Secure.ANDROID_ID` — real but not foolproof: it resets on a
/// factory reset, and differs across a dual-boot/multi-user profile. Good
/// enough to raise the bar on casual trial-abuse, not a fraud-proof
/// hardware fingerprint.
abstract final class DeviceIdentity {
  static Future<String> androidId() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.id;
  }
}
