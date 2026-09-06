import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config/app_environment.dart';

/// The running build's package info — read once per app process. Shared
/// across every page that displays the current version (About & pembaruan,
/// Profil's footer) so they can never drift from each other or from the
/// hardcoded pubspec value this replaced.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// A release row from `public.app_releases` that is newer than the build
/// currently running, as decided by [UpdateCheckerController]. `forceUpdate`
/// is precomputed here (rather than re-read from `PackageInfo` at dialog
/// build time) so the widget that shows the dialog doesn't need to redo the
/// version-code comparison itself.
class PendingAppUpdate {
  const PendingAppUpdate({
    required this.versionName,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  final String versionName;
  final String apkUrl;
  final String? changelog;

  /// True when the current build is below `min_supported_version_code`
  /// — the update dialog must be non-dismissible in that case.
  final bool forceUpdate;
}

/// Self-hosted APK update check (this app is sideloaded, not distributed via
/// Play Store, so there is no store-side update mechanism). Reads the latest
/// row of `public.app_releases` via the anon Supabase client — works whether
/// or not the rider is signed in — and compares its `version_code` against
/// the running build's `PackageInfo.buildNumber`.
///
/// Follows the exact "run once after launch" convention already established
/// by `AppConfigController`: the check starts from this `Notifier`'s
/// `build()`, which runs the first time something reads this provider (see
/// `HomePage`'s `ref.listen`, mirroring how `TemanKeretaApp` reads
/// `appConfigControllerProvider`). Best-effort by design — matches
/// `AppConfigController._load()`'s `on Object` catch-and-ignore posture, so a
/// failed update check can never block or crash app startup.
class UpdateCheckerController extends Notifier<PendingAppUpdate?> {
  @override
  PendingAppUpdate? build() {
    if (!AppEnvironment.supabaseEnabled) {
      return null;
    }
    unawaited(_check());
    return null;
  }

  Future<void> _check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final row = await Supabase.instance.client
          .from('app_releases')
          .select(
            'version_code, version_name, apk_url, changelog, min_supported_version_code',
          )
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return;
      }

      final latestVersionCode = row['version_code'] as int;
      if (latestVersionCode <= currentVersionCode) {
        return;
      }

      final minSupportedVersionCode = row['min_supported_version_code'] as int?;
      state = PendingAppUpdate(
        versionName: row['version_name'] as String,
        apkUrl: row['apk_url'] as String,
        changelog: row['changelog'] as String?,
        forceUpdate: minSupportedVersionCode != null &&
            currentVersionCode < minSupportedVersionCode,
      );
    } on Object {
      // Best-effort: if app_releases can't be reached, the app just behaves
      // as if no update is available rather than blocking startup on it.
    }
  }
}

final updateCheckerControllerProvider =
    NotifierProvider<UpdateCheckerController, PendingAppUpdate?>(
      UpdateCheckerController.new,
    );

/// Shows the "an update is available" dialog for [update]. Called from
/// `HomePage`'s `ref.listen(updateCheckerControllerProvider, ...)`. When
/// [PendingAppUpdate.forceUpdate] is true the dialog has no "Nanti" button
/// and no close affordance (`PopScope(canPop: false)`,
/// `barrierDismissible: false`) — PRD-style hard gate for a build below
/// `min_supported_version_code`. Otherwise it's a normal dismissible dialog.
///
/// "Update Sekarang" hands off to the OS browser via `url_launcher`
/// (`LaunchMode.externalApplication`) rather than downloading the APK
/// in-app — the browser download triggers Android's normal "install unknown
/// apps" consent flow on its own, which is the deliberately simpler choice
/// here over implementing `REQUEST_INSTALL_PACKAGES` handling.
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  PendingAppUpdate update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.forceUpdate,
    builder: (dialogContext) {
      return PopScope(
        canPop: !update.forceUpdate,
        child: AlertDialog(
          title: Text(
            update.forceUpdate
                ? 'Pembaruan wajib tersedia'
                : 'Pembaruan tersedia',
          ),
          // `AlertDialog.content` does not scroll on its own: it lays its
          // child out at whatever height that child asks for, and clips
          // whatever exceeds the dialog's max height. A release with more
          // than a handful of changelog lines was therefore simply cut off
          // with no way to reach the rest. A `SingleChildScrollView` inside
          // a height-capped box makes the changelog scrollable while
          // keeping short ones exactly as compact as they were.
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    update.forceUpdate
                        ? 'Versi ${update.versionName} wajib dipasang untuk terus menggunakan Teman Kereta.'
                        : 'Versi ${update.versionName} sudah tersedia.',
                  ),
                  if (update.changelog case final changelog?
                      when changelog.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Yang baru',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(changelog.trim()),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            if (!update.forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Nanti'),
              ),
            FilledButton(
              onPressed: () {
                unawaited(
                  launchUrl(
                    Uri.parse(update.apkUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                );
                if (!update.forceUpdate) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Update Sekarang'),
            ),
          ],
        ),
      );
    },
  );
}
