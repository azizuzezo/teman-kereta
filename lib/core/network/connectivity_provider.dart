import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network connection — checked once
/// immediately, then kept live via [Connectivity.onConnectivityChanged].
/// This reflects network-interface state (Wi-Fi/mobile data/ethernet vs.
/// none), not a true internet-reachability probe, matching what
/// `connectivity_plus` can observe without an extra network call.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield !initial.contains(ConnectivityResult.none);
  yield* connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});
