import 'package:flutter/foundation.dart';

enum AnalyticsEventType {
  screenView,
  action,
  error,
  auth,
  appointment,
  chat,
  medicalCard,
  settings,
}

class AnalyticsEvent {
  final AnalyticsEventType type;
  final String name;
  final Map<String, dynamic>? properties;

  AnalyticsEvent({
    required this.type,
    required this.name,
    this.properties,
  });
}

abstract class AnalyticsProvider {
  void trackEvent(AnalyticsEvent event);
  void setUserId(String? userId);
  void setUserProperty(String key, String value);
}

class ConsoleAnalyticsProvider implements AnalyticsProvider {
  @override
  void trackEvent(AnalyticsEvent event) {
    debugPrint('[Analytics] ${event.type.name}: ${event.name} ${event.properties ?? ''}');
  }

  @override
  void setUserId(String? userId) {
    debugPrint('[Analytics] User ID: $userId');
  }

  @override
  void setUserProperty(String key, String value) {
    debugPrint('[Analytics] Property: $key = $value');
  }
}

class AnalyticsService {
  late final AnalyticsProvider _provider;

  AnalyticsService({AnalyticsProvider? provider}) {
    _provider = provider ?? ConsoleAnalyticsProvider();
  }

  void setProvider(AnalyticsProvider provider) {
    _provider = provider;
  }

  void trackScreenView(String screenName) {
    _provider.trackEvent(AnalyticsEvent(
      type: AnalyticsEventType.screenView,
      name: screenName,
    ));
  }

  void trackAction(String action, {Map<String, dynamic>? properties}) {
    _provider.trackEvent(AnalyticsEvent(
      type: AnalyticsEventType.action,
      name: action,
      properties: properties,
    ));
  }

  void trackError(String error, {Map<String, dynamic>? properties}) {
    _provider.trackEvent(AnalyticsEvent(
      type: AnalyticsEventType.error,
      name: error,
      properties: properties,
    ));
  }

  void trackAuth(String action, {Map<String, dynamic>? properties}) {
    _provider.trackEvent(AnalyticsEvent(
      type: AnalyticsEventType.auth,
      name: action,
      properties: properties,
    ));
  }

  void trackAppointment(String action, {Map<String, dynamic>? properties}) {
    _provider.trackEvent(AnalyticsEvent(
      type: AnalyticsEventType.appointment,
      name: action,
      properties: properties,
    ));
  }

  void identify(String? userId) {
    _provider.setUserId(userId);
  }
}
