import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingKey = 'onboarding_complete';
const _themeKey = 'theme_mode';
const _reduceMotionKey = 'reduce_motion';
const _offlineModeKey = 'offline_mode';
const _favoriteRouteKey = 'favorite_route';
const _activeTripKey = 'active_trip_snapshot';
const _homeStationKey = 'home_station_id';
const _workStationKey = 'work_station_id';
const _rideDetectionEnabledKey = 'ride_detection_enabled';
const _rideDetectionSuppressedUntilKey = 'ride_detection_suppressed_until';
const _vibrationEnabledKey = 'notification_vibration_enabled';
const _soundEnabledKey = 'notification_sound_enabled';
const _stopAlertThresholdKey = 'notification_stop_alert_threshold';
const _textScaleKey = 'accessibility_text_scale';

class StoredPreferences {
  const StoredPreferences({
    this.onboardingComplete = false,
    this.themeMode = ThemeMode.system,
    this.reduceMotion = false,
    this.offlineMode = false,
    this.favoriteRoute,
    this.activeTripSnapshot,
    this.homeStationId,
    this.workStationId,
    this.rideDetectionEnabled = false,
    this.rideDetectionSuppressedUntil,
    this.vibrationEnabled = true,
    this.soundEnabled = true,
    this.stopAlertThreshold = 3,
    this.textScale = 1.0,
  });

  final bool onboardingComplete;
  final ThemeMode themeMode;
  final bool reduceMotion;
  final bool offlineMode;
  final String? favoriteRoute;
  final String? activeTripSnapshot;
  final String? homeStationId;
  final String? workStationId;
  final bool rideDetectionEnabled;

  /// ISO-8601 date (yyyy-MM-dd, local) up to and including which ride
  /// detection prompts are suppressed after the user picks "jangan tanya
  /// lagi hari ini".
  final String? rideDetectionSuppressedUntil;

  final bool vibrationEnabled;
  final bool soundEnabled;

  /// How many stations before the destination the countdown alerts begin
  /// (PRD §11: "lima/tiga/dua/satu stasiun sebelumnya").
  final int stopAlertThreshold;

  /// Dynamic text scale factor for PRD §33's "Dynamic text scaling".
  final double textScale;

  StoredPreferences copyWith({
    bool? onboardingComplete,
    ThemeMode? themeMode,
    bool? reduceMotion,
    bool? offlineMode,
    Object? favoriteRoute = _unset,
    Object? activeTripSnapshot = _unset,
    Object? homeStationId = _unset,
    Object? workStationId = _unset,
    bool? rideDetectionEnabled,
    Object? rideDetectionSuppressedUntil = _unset,
    bool? vibrationEnabled,
    bool? soundEnabled,
    int? stopAlertThreshold,
    double? textScale,
  }) {
    return StoredPreferences(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeMode: themeMode ?? this.themeMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      offlineMode: offlineMode ?? this.offlineMode,
      favoriteRoute: identical(favoriteRoute, _unset)
          ? this.favoriteRoute
          : favoriteRoute as String?,
      activeTripSnapshot: identical(activeTripSnapshot, _unset)
          ? this.activeTripSnapshot
          : activeTripSnapshot as String?,
      homeStationId: identical(homeStationId, _unset)
          ? this.homeStationId
          : homeStationId as String?,
      workStationId: identical(workStationId, _unset)
          ? this.workStationId
          : workStationId as String?,
      rideDetectionEnabled: rideDetectionEnabled ?? this.rideDetectionEnabled,
      rideDetectionSuppressedUntil: identical(rideDetectionSuppressedUntil, _unset)
          ? this.rideDetectionSuppressedUntil
          : rideDetectionSuppressedUntil as String?,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      stopAlertThreshold: stopAlertThreshold ?? this.stopAlertThreshold,
      textScale: textScale ?? this.textScale,
    );
  }
}

/// Sentinel distinguishing "leave unchanged" from "set to null" for nullable
/// `copyWith` fields.
const _unset = Object();

abstract interface class PreferencesStore {
  StoredPreferences get snapshot;

  Future<void> setActiveTripSnapshot(String? value);

  Future<void> setFavoriteRoute(String? value);

  Future<void> setOfflineMode(bool value);

  Future<void> setOnboardingComplete(bool value);

  Future<void> setReduceMotion(bool value);

  Future<void> setThemeMode(ThemeMode value);

  Future<void> setHomeStation(String? stationId);

  Future<void> setWorkStation(String? stationId);

  Future<void> setRideDetectionEnabled(bool value);

  Future<void> setRideDetectionSuppressedUntil(String? isoDate);

  Future<void> setVibrationEnabled(bool value);

  Future<void> setSoundEnabled(bool value);

  Future<void> setStopAlertThreshold(int value);

  Future<void> setTextScale(double value);
}

class SharedPreferencesStore implements PreferencesStore {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  StoredPreferences _snapshot = const StoredPreferences();

  @override
  StoredPreferences get snapshot => _snapshot;

  Future<void> load() async {
    final values = await Future.wait<Object?>(<Future<Object?>>[
      _preferences.getBool(_onboardingKey),
      _preferences.getString(_themeKey),
      _preferences.getBool(_reduceMotionKey),
      _preferences.getBool(_offlineModeKey),
      _preferences.getString(_favoriteRouteKey),
      _preferences.getString(_activeTripKey),
      _preferences.getString(_homeStationKey),
      _preferences.getString(_workStationKey),
      _preferences.getBool(_rideDetectionEnabledKey),
      _preferences.getString(_rideDetectionSuppressedUntilKey),
      _preferences.getBool(_vibrationEnabledKey),
      _preferences.getBool(_soundEnabledKey),
      _preferences.getInt(_stopAlertThresholdKey),
      _preferences.getDouble(_textScaleKey),
    ]);

    _snapshot = StoredPreferences(
      onboardingComplete: values[0] as bool? ?? false,
      themeMode: _decodeTheme(values[1] as String?),
      reduceMotion: values[2] as bool? ?? false,
      offlineMode: values[3] as bool? ?? false,
      favoriteRoute: values[4] as String?,
      activeTripSnapshot: values[5] as String?,
      homeStationId: values[6] as String?,
      workStationId: values[7] as String?,
      rideDetectionEnabled: values[8] as bool? ?? false,
      rideDetectionSuppressedUntil: values[9] as String?,
      vibrationEnabled: values[10] as bool? ?? true,
      soundEnabled: values[11] as bool? ?? true,
      stopAlertThreshold: values[12] as int? ?? 3,
      textScale: values[13] as double? ?? 1.0,
    );
  }

  @override
  Future<void> setActiveTripSnapshot(String? value) async {
    await _setNullableString(_activeTripKey, value);
    _snapshot = _snapshot.copyWith(activeTripSnapshot: value);
  }

  @override
  Future<void> setFavoriteRoute(String? value) async {
    await _setNullableString(_favoriteRouteKey, value);
    _snapshot = _snapshot.copyWith(favoriteRoute: value);
  }

  @override
  Future<void> setOfflineMode(bool value) async {
    await _preferences.setBool(_offlineModeKey, value);
    _snapshot = _snapshot.copyWith(offlineMode: value);
  }

  @override
  Future<void> setOnboardingComplete(bool value) async {
    await _preferences.setBool(_onboardingKey, value);
    _snapshot = _snapshot.copyWith(onboardingComplete: value);
  }

  @override
  Future<void> setReduceMotion(bool value) async {
    await _preferences.setBool(_reduceMotionKey, value);
    _snapshot = _snapshot.copyWith(reduceMotion: value);
  }

  @override
  Future<void> setThemeMode(ThemeMode value) async {
    await _preferences.setString(_themeKey, value.name);
    _snapshot = _snapshot.copyWith(themeMode: value);
  }

  @override
  Future<void> setHomeStation(String? stationId) async {
    await _setNullableString(_homeStationKey, stationId);
    _snapshot = _snapshot.copyWith(homeStationId: stationId);
  }

  @override
  Future<void> setWorkStation(String? stationId) async {
    await _setNullableString(_workStationKey, stationId);
    _snapshot = _snapshot.copyWith(workStationId: stationId);
  }

  @override
  Future<void> setRideDetectionEnabled(bool value) async {
    await _preferences.setBool(_rideDetectionEnabledKey, value);
    _snapshot = _snapshot.copyWith(rideDetectionEnabled: value);
  }

  @override
  Future<void> setRideDetectionSuppressedUntil(String? isoDate) async {
    await _setNullableString(_rideDetectionSuppressedUntilKey, isoDate);
    _snapshot = _snapshot.copyWith(rideDetectionSuppressedUntil: isoDate);
  }

  @override
  Future<void> setVibrationEnabled(bool value) async {
    await _preferences.setBool(_vibrationEnabledKey, value);
    _snapshot = _snapshot.copyWith(vibrationEnabled: value);
  }

  @override
  Future<void> setSoundEnabled(bool value) async {
    await _preferences.setBool(_soundEnabledKey, value);
    _snapshot = _snapshot.copyWith(soundEnabled: value);
  }

  @override
  Future<void> setStopAlertThreshold(int value) async {
    await _preferences.setInt(_stopAlertThresholdKey, value);
    _snapshot = _snapshot.copyWith(stopAlertThreshold: value);
  }

  @override
  Future<void> setTextScale(double value) async {
    await _preferences.setDouble(_textScaleKey, value);
    _snapshot = _snapshot.copyWith(textScale: value);
  }

  Future<void> _setNullableString(String key, String? value) {
    return value == null
        ? _preferences.remove(key)
        : _preferences.setString(key, value);
  }

  static ThemeMode _decodeTheme(String? value) {
    return ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
        ThemeMode.system;
  }
}

class MemoryPreferencesStore implements PreferencesStore {
  MemoryPreferencesStore({StoredPreferences? initial})
    : _snapshot = initial ?? const StoredPreferences();

  StoredPreferences _snapshot;

  @override
  StoredPreferences get snapshot => _snapshot;

  @override
  Future<void> setActiveTripSnapshot(String? value) async {
    _snapshot = _snapshot.copyWith(activeTripSnapshot: value);
  }

  @override
  Future<void> setFavoriteRoute(String? value) async {
    _snapshot = _snapshot.copyWith(favoriteRoute: value);
  }

  @override
  Future<void> setOfflineMode(bool value) async {
    _snapshot = _snapshot.copyWith(offlineMode: value);
  }

  @override
  Future<void> setOnboardingComplete(bool value) async {
    _snapshot = _snapshot.copyWith(onboardingComplete: value);
  }

  @override
  Future<void> setReduceMotion(bool value) async {
    _snapshot = _snapshot.copyWith(reduceMotion: value);
  }

  @override
  Future<void> setThemeMode(ThemeMode value) async {
    _snapshot = _snapshot.copyWith(themeMode: value);
  }

  @override
  Future<void> setHomeStation(String? stationId) async {
    _snapshot = _snapshot.copyWith(homeStationId: stationId);
  }

  @override
  Future<void> setWorkStation(String? stationId) async {
    _snapshot = _snapshot.copyWith(workStationId: stationId);
  }

  @override
  Future<void> setRideDetectionEnabled(bool value) async {
    _snapshot = _snapshot.copyWith(rideDetectionEnabled: value);
  }

  @override
  Future<void> setRideDetectionSuppressedUntil(String? isoDate) async {
    _snapshot = _snapshot.copyWith(rideDetectionSuppressedUntil: isoDate);
  }

  @override
  Future<void> setVibrationEnabled(bool value) async {
    _snapshot = _snapshot.copyWith(vibrationEnabled: value);
  }

  @override
  Future<void> setSoundEnabled(bool value) async {
    _snapshot = _snapshot.copyWith(soundEnabled: value);
  }

  @override
  Future<void> setStopAlertThreshold(int value) async {
    _snapshot = _snapshot.copyWith(stopAlertThreshold: value);
  }

  @override
  Future<void> setTextScale(double value) async {
    _snapshot = _snapshot.copyWith(textScale: value);
  }
}

final preferencesStoreProvider = Provider<PreferencesStore>((Ref ref) {
  throw StateError('PreferencesStore harus di-override saat bootstrap.');
});
