import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static String formatDate(String iso, {String locale = 'fr'}) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    final fmt = DateFormat.yMMMd(locale);
    return fmt.format(date);
  }

  static String formatTime(String iso, {String locale = 'fr'}) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    final fmt = DateFormat.Hm(locale);
    return fmt.format(date);
  }

  static String formatDateTime(String iso, {String locale = 'fr'}) {
    return '${formatDate(iso, locale: locale)} ${formatTime(iso, locale: locale)}';
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

  static String formatRelativeTime(String iso, {String locale = 'fr'}) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    if (diff.inDays < 30) return 'Il y a ${diff.inDays ~/ 7} sem';
    return formatDate(iso, locale: locale);
  }
}
