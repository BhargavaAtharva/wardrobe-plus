const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "1 item", "3 items"
String plural(int n, String word) => '$n ${n == 1 ? word : '${word}s'}';

DateTime? parseDate(Object? value) => value is String ? DateTime.tryParse(value) : null;

/// "Today", "Yesterday", "5 days ago", "3 weeks ago", or "Never".
String wornAgo(Object? isoDate, {DateTime? now}) {
  final date = parseDate(isoDate);
  if (date == null) return 'Never';
  final today = _day(now ?? DateTime.now());
  final days = today.difference(_day(date)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 14) return '$days days ago';
  if (days < 60) return '${days ~/ 7} weeks ago';
  return '${days ~/ 30} months ago';
}

int? daysSince(Object? isoDate, {DateTime? now}) {
  final date = parseDate(isoDate);
  if (date == null) return null;
  return _day(now ?? DateTime.now()).difference(_day(date)).inDays;
}

/// "8 Oct" this year, "8 Oct 2025" otherwise.
String shortDate(Object? isoDate, {DateTime? now}) {
  final d = parseDate(isoDate);
  if (d == null) return '—';
  final sameYear = d.year == (now ?? DateTime.now()).year;
  return sameYear ? '${d.day} ${_months[d.month - 1]}' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "Today", "Yesterday" or "Wed, 8 Oct"
String dayHeading(DateTime date, {DateTime? now}) {
  final days = _day(now ?? DateTime.now()).difference(_day(date)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
}

/// Converts a stored local timestamp to UTC ISO for the server.
String? toUtcIso(Object? isoDate) => parseDate(isoDate)?.toUtc().toIso8601String();

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
