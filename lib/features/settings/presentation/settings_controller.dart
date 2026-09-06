import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_store.dart';

class AppSettings {
  const AppSettings({
    required this.onboardingComplete,
    required this.themeMode,
    required this.reduceMotion,
    required this.homeStationId,
    required this.workStationId,
    required this.homeAddress,
    required this.workAddress,
    required this.rideDetectionEnabled,
    required this.vibrationEnabled,
    required this.soundEnabled,
    required this.stopAlertThreshold,
    required this.textScale,
  });

  final bool onboardingComplete;
  final ThemeMode themeMode;
  final bool reduceMotion;
  final String? homeStationId;
  final String? workStationId;
  final String? homeAddress;
  final String? workAddress;
  final bool rideDetectionEnabled;
  final bool vibrationEnabled;
  final bool soundEnabled;
  final int stopAlertThreshold;
  final double textScale;

  AppSettings copyWith({
    bool? onboardingComplete,
    ThemeMode? themeMode,
    bool? reduceMotion,
    Object? homeStationId = _unset,
    Object? workStationId = _unset,
    Object? homeAddress = _unset,
    Object? workAddress = _unset,
    bool? rideDetectionEnabled,
    bool? vibrationEnabled,
    bool? soundEnabled,
    int? stopAlertThreshold,
    double? textScale,
  }) {
    return AppSettings(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themeMode: themeMode ?? this.themeMode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
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
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      stopAlertThreshold: stopAlertThreshold ?? this.stopAlertThreshold,
      textScale: textScale ?? this.textScale,
    );
  }
}

const _unset = Object();

class SettingsController extends Notifier<AppSettings> {
  late final PreferencesStore _store;

  @override
  AppSettings build() {
    _store = ref.watch(preferencesStoreProvider);
    final snapshot = _store.snapshot;
    return AppSettings(
      onboardingComplete: snapshot.onboardingComplete,
      themeMode: snapshot.themeMode,
      reduceMotion: snapshot.reduceMotion,
      homeStationId: snapshot.homeStationId,
      workStationId: snapshot.workStationId,
      homeAddress: snapshot.homeAddress,
      workAddress: snapshot.workAddress,
      rideDetectionEnabled: snapshot.rideDetectionEnabled,
      vibrationEnabled: snapshot.vibrationEnabled,
      soundEnabled: snapshot.soundEnabled,
      stopAlertThreshold: snapshot.stopAlertThreshold,
      textScale: snapshot.textScale,
    );
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _store.setOnboardingComplete(true);
  }

  Future<void> resetOnboarding() async {
    state = state.copyWith(onboardingComplete: false);
    await _store.setOnboardingComplete(false);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _store.setReduceMotion(value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    state = state.copyWith(themeMode: value);
    await _store.setThemeMode(value);
  }

  Future<void> setHomeStation(String? stationId) async {
    state = state.copyWith(homeStationId: stationId);
    await _store.setHomeStation(stationId);
  }

  Future<void> setWorkStation(String? stationId) async {
    state = state.copyWith(workStationId: stationId);
    await _store.setWorkStation(stationId);
  }

  Future<void> setHomeAddress(String? address) async {
    state = state.copyWith(homeAddress: address);
    await _store.setHomeAddress(address);
  }

  Future<void> setWorkAddress(String? address) async {
    state = state.copyWith(workAddress: address);
    await _store.setWorkAddress(address);
  }

  Future<void> setRideDetectionEnabled(bool value) async {
    state = state.copyWith(rideDetectionEnabled: value);
    await _store.setRideDetectionEnabled(value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await _store.setVibrationEnabled(value);
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _store.setSoundEnabled(value);
  }

  Future<void> setStopAlertThreshold(int value) async {
    state = state.copyWith(stopAlertThreshold: value);
    await _store.setStopAlertThreshold(value);
  }

  Future<void> setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    await _store.setTextScale(value);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
