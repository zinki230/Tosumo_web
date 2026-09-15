import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  /// Formats a date from either DateTime object or ISO string
  static String formatDate(dynamic dateOrIso, {String locale = 'fr'}) {
    DateTime? date;
    if (dateOrIso is DateTime) {
      date = dateOrIso;
    } else if (dateOrIso is String) {
      date = DateTime.tryParse(dateOrIso);
      if (date == null) return dateOrIso;
    } else {
      return 'Invalid date';
    }
    final fmt = DateFormat.yMMMd(locale);
    return fmt.format(date);
  }

  /// Formats time from either DateTime object or ISO string
  static String formatTime(dynamic dateOrIso, {String locale = 'fr'}) {
    DateTime? date;
    if (dateOrIso is DateTime) {
      date = dateOrIso;
    } else if (dateOrIso is String) {
      date = DateTime.tryParse(dateOrIso);
      if (date == null) return dateOrIso;
    } else {
      return 'Invalid time';
    }
    final fmt = DateFormat.Hm(locale);
    return fmt.format(date);
  }

  /// Formats both date and time
  static String formatDateTime(dynamic dateOrIso, {String locale = 'fr'}) {
    return '${formatDate(dateOrIso, locale: locale)} ${formatTime(dateOrIso, locale: locale)}';
  }

  static String getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  static String formatDistance(String distance) {
    return distance;
  }

  /// Formats relative time (e.g., "Il y a 2h")
  static String formatRelativeTime(dynamic dateOrIso, {String locale = 'fr'}) {
    DateTime? date;
    if (dateOrIso is DateTime) {
      date = dateOrIso;
    } else if (dateOrIso is String) {
      date = DateTime.tryParse(dateOrIso);
      if (date == null) return dateOrIso;
    } else {
      return 'Invalid date';
    }
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    if (diff.inDays < 30) return 'Il y a ${diff.inDays ~/ 7} sem';
    return formatDate(date, locale: locale);
  }
}
