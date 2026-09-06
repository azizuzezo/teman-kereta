import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/empty_state.dart';
import '../../features/account/presentation/login_page.dart';
import '../../features/account/presentation/reset_password_page.dart';
import '../../features/account/presentation/set_username_page.dart';
import '../../features/active_trip/presentation/active_trip_page.dart';
import '../../features/forum/presentation/forum_feed_page.dart';
import '../../features/forum/presentation/forum_post_composer_page.dart';
import '../../features/forum/presentation/forum_post_detail_page.dart';
import '../../features/history/presentation/notification_center_page.dart';
import '../../features/history/presentation/trip_history_page.dart';
import '../../features/history/presentation/trip_recap_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/live_map/presentation/live_map_page.dart';
import '../../features/multimodal/presentation/multimodal_route_page.dart';
import '../../features/nearby_places/presentation/explore_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/ride_detection/presentation/ride_detection_confirm_page.dart';
import '../../features/ride_detection/presentation/ride_detection_watcher.dart';
import '../../features/schedule/presentation/schedule_page.dart';
import '../../features/schedule/presentation/trip_detail_page.dart';
import '../../features/schedule/presentation/trip_search_page.dart';
import '../../features/settings/presentation/accessibility_settings_page.dart';
import '../../features/settings/presentation/location_settings_page.dart';
import '../../features/settings/presentation/notification_settings_page.dart';
import '../../features/settings/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_controller.dart';
import '../../features/settings/presentation/sound_test_page.dart';
import '../../features/settings/presentation/widget_settings_page.dart';
import '../../features/social/presentation/followers_list_page.dart';
import '../../features/social/presentation/following_list_page.dart';
import '../../features/social/presentation/user_profile_page.dart';
import '../../features/social/presentation/user_search_page.dart';
import '../../features/stations/presentation/nearby_stations_page.dart';
import '../../features/stations/presentation/station_detail_page.dart';
import '../../features/support/presentation/app_update_page.dart';
import '../../features/support/presentation/support_pages.dart';
import '../config/app_environment.dart';
import 'main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Routes reachable while the login gate below is otherwise blocking
/// navigation — the login/signup page itself, password reset (reached from
/// a deep link that may arrive before/without a session), and the
/// mandatory post-signup username page (reached from the login page, which
/// a signed-in-but-no-username user should land on rather than bounce
/// between it and the login redirect).
const _authGateExemptRoutes = <String>{
  '/account/login',
  '/account/reset-password',
  '/account/set-username',
};

/// Bridges a `Stream` (here, Supabase's auth-state-change stream) to a
/// `Listenable` so `GoRouter`'s `refreshListenable` re-runs `redirect`
/// immediately on sign-in/sign-out — without this, a sign-out only bounces
/// the user back to the login screen on their next explicit navigation.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((Ref ref) {
  _GoRouterRefreshStream? authRefresh;
  if (AppEnvironment.supabaseEnabled) {
    authRefresh = _GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    );
    ref.onDispose(authRefresh.dispose);
  }

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: ref.read(settingsControllerProvider).onboardingComplete
        ? '/'
        : '/onboarding',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final onboardingComplete = ref
          .read(settingsControllerProvider)
          .onboardingComplete;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboardingComplete && !atOnboarding) {
        return '/onboarding';
      }
      if (onboardingComplete && atOnboarding) {
        return '/';
      }

      // Login is mandatory once onboarding is done: every route except the
      // ones above requires a signed-in Supabase user.
      if (onboardingComplete && AppEnvironment.supabaseEnabled) {
        final loggedIn = Supabase.instance.client.auth.currentUser != null;
        final atExemptRoute = _authGateExemptRoutes.contains(
          state.matchedLocation,
        );
        if (!loggedIn && !atExemptRoute) {
          return '/account/login';
        }
        if (loggedIn && state.matchedLocation == '/account/login') {
          return '/';
        }
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return RideDetectionWatcher(
            child: MainShell(navigationShell: navigationShell),
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const SchedulePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/map',
                builder: (context, state) => const LiveMapPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/explore',
                builder: (context, state) => ExplorePage(
                  key: state.pageKey,
                  initialStationId:
                      state.uri.queryParameters['station'] ?? 'SUD',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/forum',
                builder: (context, state) => const ForumFeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/schedule/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TripSearchPage(),
      ),
      GoRoute(
        path: '/station/:stationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StationDetailPage(
          stationId: state.pathParameters['stationId']!,
        ),
      ),
      GoRoute(
        path: '/trip/:tripId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            TripDetailPage(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/active-trip',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ActiveTripPage(),
      ),
      GoRoute(
        path: '/trip-complete',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TripCompletePage(),
      ),
      GoRoute(
        path: '/help',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HelpPage(),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PrivacyPage(),
      ),
      GoRoute(
        path: '/report',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportPage(),
      ),
      GoRoute(
        path: '/ride-detection',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RideDetectionConfirmPage(),
      ),
      GoRoute(
        path: '/nearby-stations',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NearbyStationsPage(),
      ),
      GoRoute(
        path: '/trip/:tripId/multimodal',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            MultimodalRoutePage(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: '/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TripHistoryPage(),
      ),
      GoRoute(
        path: '/history/recap',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TripRecapPage(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppUpdatePage(),
      ),
      GoRoute(
        path: '/settings/location',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LocationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/settings/sound-test',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SoundTestPage(),
      ),
      GoRoute(
        path: '/settings/accessibility',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccessibilitySettingsPage(),
      ),
      GoRoute(
        path: '/settings/widgets',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WidgetSettingsPage(),
      ),
      GoRoute(
        path: '/forum/compose',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForumPostComposerPage(),
      ),
      GoRoute(
        path: '/forum/post/:postId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ForumPostDetailPage(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/social/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UserSearchPage(),
      ),
      GoRoute(
        path: '/social/user/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            UserProfilePage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/social/followers/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            FollowersListPage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/social/following/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            FollowingListPage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/account/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/account/reset-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/account/set-username',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SetUsernamePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: AppEmptyState(
        icon: Icons.route_outlined,
        title: 'Rute tidak tersedia',
        message: state.error?.toString() ?? 'Kembali ke beranda.',
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Ke beranda'),
        ),
      ),
    ),
  );
  // Handle Supabase PASSWORD_RECOVERY deep link.
  // When user clicks the reset-password email link (temankereta://app/account/reset-password),
  // Supabase fires a PASSWORD_RECOVERY event so we navigate to the set-new-password page.
  if (AppEnvironment.supabaseEnabled) {
    try {
      final authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.passwordRecovery) {
          router.push('/account/reset-password');
        }
      });
      ref.onDispose(authSub.cancel);
    } catch (_) {}
  }
  ref.onDispose(router.dispose);
  return router;
});
