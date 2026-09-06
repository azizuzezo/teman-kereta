import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/config/app_environment.dart';

/// Helper function to check if user is authenticated before executing an action.
/// If not authenticated, displays an informative dialog directing the user to login.
bool checkAuthOrPrompt(
  BuildContext context, {
  required String featureName,
  required VoidCallback onAllowed,
}) {
  User? currentUser;
  if (AppEnvironment.supabaseEnabled) {
    try {
      currentUser = Supabase.instance.client.auth.currentUser;
    } catch (_) {}
  }

  // If Supabase is disabled or user is logged in, proceed.
  if (!AppEnvironment.supabaseEnabled || currentUser != null) {
    onAllowed();
    return true;
  }

  // Otherwise, prompt user to log in / sign up first.
  unawaited(
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Info Masuk Akun'),
        content: Text(
          'Silakan daftar dulu atau masuk akun terlebih dahulu untuk menggunakan fitur $featureName.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/account/login');
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Masuk / Daftar'),
          ),
        ],
      ),
    ),
  );

  return false;
}
