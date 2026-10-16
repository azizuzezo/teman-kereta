import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Canonical public destinations used by About, Privacy, Help and Report.
abstract final class SupportLinks {
  static const String website = 'https://temankereta.web.id';
  static const String privacyPolicy = 'https://temankereta.web.id/privacy';
  static const String deleteAccount =
      'https://temankereta.web.id/delete-account';
  static const String supportEmail = 'support@temankereta.web.id';

  static Uri get mailto => Uri(scheme: 'mailto', path: supportEmail);
}

/// Opens [uri] outside the app. Shows a snackbar naming the address when no
/// app can handle it, so the control never fails silently.
Future<void> openExternal(
  BuildContext context,
  Uri uri, {
  String? fallbackLabel,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Tidak ada aplikasi yang bisa membuka ${fallbackLabel ?? uri.toString()}.',
        ),
      ),
    );
  }
}
