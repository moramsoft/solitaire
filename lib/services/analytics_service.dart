import 'package:flutter/foundation.dart';

/// Recorded analytics event payload.
class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.params,
    required this.timestamp,
  });

  final String name;
  final Map<String, Object?> params;
  final DateTime timestamp;
}

/// Analytics interface allowing seamless swap to Firebase Analytics in v1.1.
abstract class AnalyticsService {
  void logEvent(
    String name, [
    Map<String, Object?> params = const <String, Object?>{},
  ]);
}

/// v1.0 debug & in-memory analytics implementation.
class DebugAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  @override
  void logEvent(
    String name, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    final event = AnalyticsEvent(
      name: name,
      params: Map<String, Object?>.unmodifiable(params),
      timestamp: DateTime.now(),
    );
    events.add(event);
    if (kDebugMode) {
      debugPrint('[Analytics] $name $params');
    }
  }
}
