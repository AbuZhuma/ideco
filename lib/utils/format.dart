import 'package:intl/intl.dart';

String formatDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return DateFormat('HH:mm', 'ru').format(d);
  if (day == today.subtract(const Duration(days: 1))) {
    return 'вчера, ${DateFormat('HH:mm', 'ru').format(d)}';
  }
  if (d.year == now.year) return DateFormat('d MMM', 'ru').format(d);
  return DateFormat('d MMM yyyy', 'ru').format(d);
}

String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n $one';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n $few';
  return '$n $many';
}
