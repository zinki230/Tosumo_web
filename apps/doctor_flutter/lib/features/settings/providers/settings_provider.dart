import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';

class SettingsState {
  final String language;
  final String theme;
  final Map<String, dynamic> notificationPreferences;
  final bool biometricEnabled;
  final bool offlineModeEnabled;
  final bool loading;
  final bool saving;
  final String? error;

  const SettingsState({
    this.language = 'fr',
    this.theme = 'light',
    this.notificationPreferences = const {},
    this.biometricEnabled = false,
    this.offlineModeEnabled = false,
    this.loading = false,
    this.saving = false,
    this.error,
  });

  SettingsState copyWith({
    String? language,
    String? theme,
    Map<String, dynamic>? notificationPreferences,
    bool? biometricEnabled,
    bool? offlineModeEnabled,
    bool? loading,
    bool? saving,
    String? error,
  }) {
    return SettingsState(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: error,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final doctor = await ref.read(doctorRepositoryProvider).getProfile(ref.read(currentDoctorIdProvider) ?? '');
      state = state.copyWith(
        language: doctor.languages.isNotEmpty ? doctor.languages.first : 'fr',
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> updateLanguage(String language) async {
    state = state.copyWith(saving: true, language: language);
    try {
      await ref.read(settingsRepositoryProvider).updateLanguage(language);
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }

  Future<void> updateTheme(String theme) async {
    state = state.copyWith(saving: true, theme: theme);
    try {
      await ref.read(settingsRepositoryProvider).updateTheme(theme);
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }

  Future<void> updateNotificationPreferences(Map<String, dynamic> prefs) async {
    state = state.copyWith(saving: true, notificationPreferences: prefs);
    try {
      await ref.read(settingsRepositoryProvider).updateNotificationPreferences(prefs);
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }

  Future<void> toggleBiometric() async {
    final newValue = !state.biometricEnabled;
    state = state.copyWith(saving: true, biometricEnabled: newValue);
    try {
      await ref.read(settingsRepositoryProvider).enableBiometric(newValue);
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }

  Future<void> toggleOfflineMode() async {
    final newValue = !state.offlineModeEnabled;
    state = state.copyWith(saving: true, offlineModeEnabled: newValue);
    try {
      await ref.read(settingsRepositoryProvider).enableOfflineMode(newValue);
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }

  Future<void> setPinCode(String pin) async {
    state = state.copyWith(saving: true);
    try {
      await ref.read(settingsRepositoryProvider).setPinCode(pin);
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
    }
  }
}
