import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingKey = 'onboarding_complete';
const _themeKey = 'theme_mode';
const _reduceMotionKey = 'reduce_motion';
const _favoriteRouteKey = 'favorite_route';
const _activeTripKey = 'active_trip_snapshot';
const _homeStationKey = 'home_station_id';
const _workStationKey = 'work_station_id';
const _homeAddressKey = 'home_address';
const _workAddressKey = 'work_address';
const _rideDetectionEnabledKey = 'ride_detection_enabled';
const _rideDetectionSuppressedUntilKey = 'ride_detection_suppressed_until';
const _vibrationEnabledKey = 'notification_vibration_enabled';
const _soundEnabledKey = 'notification_sound_enabled';
const _stopAlertThresholdKey = 'notification_stop_alert_threshold';
const _textScaleKey = 'accessibility_text_scale';
const _deviceSessionIdKey = 'crowd_position_device_session_id';
const _guestDisplayNameKey = 'guest_display_name';
const _dailyRouteEnabledKey = 'daily_route_enabled';
const _dailyRouteFromKey = 'daily_route_from_station_id';
const _dailyRouteToKey = 'daily_route_to_station_id';

class StoredPreferences {
  const StoredPreferences({
    this.onboardingComplete = false,
    this.themeMode = ThemeMode.system,
    this.reduceMotion = false,
    this.favoriteRoute,
    this.activeTripSnapshot,
    this.homeStationId,
    this.workStationId,
    this.homeAddress,
    this.workAddress,
    this.rideDetectionEnabled = false,
    this.rideDetectionSuppressedUntil,
    this.vibrationEnabled = true,
    this.soundEnabled = true,
    this.stopAlertThreshold = 3,
    this.textScale = 1.0,
    this.deviceSessionId,
    this.guestDisplayName,
    this.dailyRouteEnabled = false,
    this.dailyRouteFromStationId,
    this.dailyRouteToStationId,
  });

  final bool onboardingComplete;
  final ThemeMode themeMode;
  final bool reduceMotion;
  final String? favoriteRoute;
  final String? activeTripSnapshot;
  final String? homeStationId;
  final String? workStationId;
  final String? homeAddress;
  final String? workAddress;
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

  /// A random per-install identifier, generated once on first use and never
  /// tied to any real account — exists only so the crowd-sourced vehicle
  /// position aggregation can count distinct reporters as a light
  /// anti-spoofing signal server-side, not to identify anyone.
  final String? deviceSessionId;
  final String? guestDisplayName;

  /// Daily commute route: when enabled + ride-detection fires at the origin
  /// station, the trip is started automatically to [dailyRouteToStationId].
  final bool dailyRouteEnabled;
  final String? dailyRouteFromStationId;
  final String? dailyRouteToStationId;

  StoredPreferences copyWith({
    bool? onboardingComplete,
    ThemeMode? themeMode,
    bool? reduceMotion,
    Object? favoriteRoute = _unset,
    Object? activeTripSnapshot = _unset,
    Object? homeStationId = _unset,
    Object? workStationId = _unset,
    Object? homeAddress = _unset,
    Object? workAddress = _unset,
    bool? rideDetectionEnabled,
    Object? rideDetectionSuppressedUntil = _unset,
    bool? vibrationEnabled,
    bool? soundEnabled,
    int? stopAlertThreshold,
    double? textScale,
    Object? deviceSessionId = _unset,
    Object? guestDisplayName = _unset,
    bool? dailyRouteEnabled,
    Object? dailyRouteFromStationId = _unset,
    Object? dailyRouteToStationId = _unset,
  }) {
    return StoredPreferences(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeMode: themeMode ?? this.themeMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
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
      homeAddress: identical(homeAddress, _unset)
          ? this.homeAddress
          : homeAddress as String?,
      workAddress: identical(workAddress, _unset)
          ? this.workAddress
          : workAddress as String?,
      rideDetectionEnabled: rideDetectionEnabled ?? this.rideDetectionEnabled,
      rideDetectionSuppressedUntil: identical(rideDetectionSuppressedUntil, _unset)
          ? this.rideDetectionSuppressedUntil
          : rideDetectionSuppressedUntil as String?,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      stopAlertThreshold: stopAlertThreshold ?? this.stopAlertThreshold,
      textScale: textScale ?? this.textScale,
      deviceSessionId: identical(deviceSessionId, _unset)
          ? this.deviceSessionId
          : deviceSessionId as String?,
      guestDisplayName: identical(guestDisplayName, _unset)
          ? this.guestDisplayName
          : guestDisplayName as String?,
      dailyRouteEnabled: dailyRouteEnabled ?? this.dailyRouteEnabled,
      dailyRouteFromStationId: identical(dailyRouteFromStationId, _unset)
          ? this.dailyRouteFromStationId
          : dailyRouteFromStationId as String?,
      dailyRouteToStationId: identical(dailyRouteToStationId, _unset)
          ? this.dailyRouteToStationId
          : dailyRouteToStationId as String?,
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

  Future<void> setOnboardingComplete(bool value);

  Future<void> setReduceMotion(bool value);

  Future<void> setThemeMode(ThemeMode value);

  Future<void> setHomeStation(String? stationId);

  Future<void> setWorkStation(String? stationId);

  Future<void> setHomeAddress(String? address);

  Future<void> setWorkAddress(String? address);

  Future<void> setRideDetectionEnabled(bool value);

  Future<void> setRideDetectionSuppressedUntil(String? isoDate);

  Future<void> setVibrationEnabled(bool value);

  Future<void> setSoundEnabled(bool value);

  Future<void> setStopAlertThreshold(int value);

  Future<void> setTextScale(double value);

  Future<void> setDeviceSessionId(String value);

  Future<void> setGuestDisplayName(String? value);

  Future<void> setDailyRouteEnabled(bool value);

  Future<void> setDailyRouteFromStation(String? stationId);

  Future<void> setDailyRouteToStation(String? stationId);
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
      _preferences.getString(_favoriteRouteKey),
      _preferences.getString(_activeTripKey),
      _preferences.getString(_homeStationKey),
      _preferences.getString(_workStationKey),
      _preferences.getString(_homeAddressKey),
      _preferences.getString(_workAddressKey),
      _preferences.getBool(_rideDetectionEnabledKey),
      _preferences.getString(_rideDetectionSuppressedUntilKey),
      _preferences.getBool(_vibrationEnabledKey),
      _preferences.getBool(_soundEnabledKey),
      _preferences.getInt(_stopAlertThresholdKey),
      _preferences.getDouble(_textScaleKey),
      _preferences.getString(_deviceSessionIdKey),
      _preferences.getString(_guestDisplayNameKey),
      _preferences.getBool(_dailyRouteEnabledKey),
      _preferences.getString(_dailyRouteFromKey),
      _preferences.getString(_dailyRouteToKey),
    ]);

    _snapshot = StoredPreferences(
      onboardingComplete: values[0] as bool? ?? false,
      themeMode: _decodeTheme(values[1] as String?),
      reduceMotion: values[2] as bool? ?? false,
      favoriteRoute: values[3] as String?,
      activeTripSnapshot: values[4] as String?,
      homeStationId: values[5] as String?,
      workStationId: values[6] as String?,
      homeAddress: values[7] as String?,
      workAddress: values[8] as String?,
      rideDetectionEnabled: values[9] as bool? ?? false,
      rideDetectionSuppressedUntil: values[10] as String?,
      vibrationEnabled: values[11] as bool? ?? true,
      soundEnabled: values[12] as bool? ?? true,
      stopAlertThreshold: values[13] as int? ?? 3,
      textScale: values[14] as double? ?? 1.0,
      deviceSessionId: values[15] as String?,
      guestDisplayName: values[16] as String?,
      dailyRouteEnabled: values[17] as bool? ?? false,
      dailyRouteFromStationId: values[18] as String?,
      dailyRouteToStationId: values[19] as String?,
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
  Future<void> setHomeAddress(String? address) async {
    await _setNullableString(_homeAddressKey, address);
    _snapshot = _snapshot.copyWith(homeAddress: address);
  }

  @override
  Future<void> setWorkAddress(String? address) async {
    await _setNullableString(_workAddressKey, address);
    _snapshot = _snapshot.copyWith(workAddress: address);
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

  @override
  Future<void> setDeviceSessionId(String value) async {
    await _preferences.setString(_deviceSessionIdKey, value);
    _snapshot = _snapshot.copyWith(deviceSessionId: value);
  }

  @override
  Future<void> setGuestDisplayName(String? value) async {
    await _setNullableString(_guestDisplayNameKey, value);
    _snapshot = _snapshot.copyWith(guestDisplayName: value);
  }

  @override
  Future<void> setDailyRouteEnabled(bool value) async {
    await _preferences.setBool(_dailyRouteEnabledKey, value);
    _snapshot = _snapshot.copyWith(dailyRouteEnabled: value);
  }

  @override
  Future<void> setDailyRouteFromStation(String? stationId) async {
    await _setNullableString(_dailyRouteFromKey, stationId);
    _snapshot = _snapshot.copyWith(dailyRouteFromStationId: stationId);
  }

  @override
  Future<void> setDailyRouteToStation(String? stationId) async {
    await _setNullableString(_dailyRouteToKey, stationId);
    _snapshot = _snapshot.copyWith(dailyRouteToStationId: stationId);
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
  Future<void> setHomeAddress(String? address) async {
    _snapshot = _snapshot.copyWith(homeAddress: address);
  }

  @override
  Future<void> setWorkAddress(String? address) async {
    _snapshot = _snapshot.copyWith(workAddress: address);
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

  @override
  Future<void> setDeviceSessionId(String value) async {
    _snapshot = _snapshot.copyWith(deviceSessionId: value);
  }

  @override
  Future<void> setGuestDisplayName(String? value) async {
    _snapshot = _snapshot.copyWith(guestDisplayName: value);
  }

  @override
  Future<void> setDailyRouteEnabled(bool value) async {
    _snapshot = _snapshot.copyWith(dailyRouteEnabled: value);
  }

  @override
  Future<void> setDailyRouteFromStation(String? stationId) async {
    _snapshot = _snapshot.copyWith(dailyRouteFromStationId: stationId);
  }

  @override
  Future<void> setDailyRouteToStation(String? stationId) async {
    _snapshot = _snapshot.copyWith(dailyRouteToStationId: stationId);
  }
}

final preferencesStoreProvider = Provider<PreferencesStore>((Ref ref) {
  throw StateError('PreferencesStore harus di-override saat bootstrap.');
});
