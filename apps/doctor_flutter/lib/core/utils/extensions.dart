import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String formatYMMMd({String locale = 'fr'}) {
    final fmt = DateFormat.yMMMd(locale);
    return fmt.format(this);
  }

  String formatHm({String locale = 'fr'}) {
    final fmt = DateFormat.Hm(locale);
    return fmt.format(this);
  }

  String formatFullDate({String locale = 'fr'}) {
    final fmt = DateFormat('EEEE d MMMM yyyy', locale);
    return fmt.format(this);
  }
}
