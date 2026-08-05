import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/empty_state.dart';
import '../../features/active_trip/presentation/active_trip_page.dart';
import '../../features/history/presentation/notification_center_page.dart';
import '../../features/history/presentation/offline_mode_page.dart';
import '../../features/history/presentation/trip_history_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/live_map/presentation/live_map_page.dart';
import '../../features/multimodal/presentation/multimodal_route_page.dart';
import '../../features/nearby_places/presentation/explore_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/ride_detection/presentation/ride_detection_confirm_page.dart';
import '../../features/ride_detection/presentation/ride_detection_watcher.dart';
import '../../features/schedule/presentation/schedule_page.dart';
import '../../features/schedule/presentation/trip_detail_page.dart';
import '../../features/settings/presentation/accessibility_settings_page.dart';
import '../../features/settings/presentation/gtfs_import_page.dart';
import '../../features/settings/presentation/location_settings_page.dart';
import '../../features/settings/presentation/notification_settings_page.dart';
import '../../features/settings/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_controller.dart';
import '../../features/settings/presentation/widget_settings_page.dart';
import '../../features/stations/presentation/nearby_stations_page.dart';
import '../../features/stations/presentation/station_detail_page.dart';
import '../../features/support/presentation/app_update_page.dart';
import '../../features/support/presentation/support_pages.dart';
import 'main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((Ref ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: ref.read(settingsControllerProvider).onboardingComplete
        ? '/'
        : '/onboarding',
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
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
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
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/offline-mode',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OfflineModePage(),
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
        path: '/settings/gtfs-import',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GtfsImportPage(),
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
  ref.onDispose(router.dispose);
  return router;
});
