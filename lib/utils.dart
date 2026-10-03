const _weekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// 12345 -> "12,345"
String fmtInt(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

/// 8250 -> "8.3k"
String compactInt(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String longDate(DateTime d) =>
    '${_weekdayLong[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
String shortWeekday(DateTime d) => _weekdayShort[d.weekday - 1];
String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';
