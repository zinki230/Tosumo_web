import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLocalization {
  final Map<String, dynamic> strings;
  final String locale;

  AppLocalization(this.strings, this.locale);

  static Future<AppLocalization> load(String locale) async {
    final jsonStr = await rootBundle.loadString(
      'assets/translations/$locale.json',
    );
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return AppLocalization(map, locale);
  }

  String t(String key, {Map<String, String>? params}) {
    final keys = key.split('.');
    dynamic value = strings;
    for (final k in keys) {
      if (value is Map<String, dynamic>) {
        value = value[k];
      } else {
        return key;
      }
    }
    if (value == null) return key;
    String result = value.toString();
    if (params != null) {
      params.forEach((k, v) {
        result = result.replaceAll('{{$k}}', v);
      });
    }
    return result;
  }
}

class _LocaleNotifier extends Notifier<String> {
  @override
  String build() => 'fr';

  void setLocale(String locale) => state = locale;
}

final localeProvider = NotifierProvider<_LocaleNotifier, String>(
  _LocaleNotifier.new,
);

final localizationProvider = FutureProvider.family<AppLocalization, String>(
  (ref, locale) => AppLocalization.load(locale),
);

Future<String> getSavedLanguage() async {
  try {
    const storage = FlutterSecureStorage();
    final saved = await storage.read(key: 'tosumo_language');
    return saved ?? 'fr';
  } catch (_) {
    return 'fr';
  }
}

Future<void> saveLanguage(String lang) async {
  try {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'tosumo_language', value: lang);
  } catch (_) {}
}
