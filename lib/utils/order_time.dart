/// Shared order-time formatting helpers.
///
/// Order timestamps arrive from the backend in UTC (e.g.
/// `2026-09-21T06:32:10.000Z`). Formatting them with `.hour`/`.minute`
/// directly shows UTC clock time — 5 hours behind Pakistan local time —
/// so an 11:32 AM order displayed as "06:32". These helpers convert to
/// device-local time first, then format.
library;

/// Parse an order timestamp from any backend representation
/// (ISO string / DateTime / epoch millis) into a local [DateTime].
DateTime? parseOrderTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  final s = raw.toString();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  return parsed?.toLocal(); // ISO strings with Z suffix convert correctly
}

/// "11:32 AM" / "6:05 PM" — clock time in device-local timezone.
String formatOrderClock(dynamic raw) {
  final t = parseOrderTime(raw);
  if (t == null) return '';
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final amPm = t.hour < 12 ? 'AM' : 'PM';
  final mins = t.minute.toString().padLeft(2, '0');
  return '$hour12:$mins $amPm';
}

/// "21 Sep" style short date (no year — orders are recent).
String formatOrderDay(dynamic raw) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final t = parseOrderTime(raw);
  if (t == null) return '';
  return '${t.day} ${months[t.month - 1]}';
}

/// "21 Sep, 11:32 AM" — date + time combined.
String formatOrderDayTime(dynamic raw) {
  final day = formatOrderDay(raw);
  if (day.isEmpty) return '';
  return '$day, ${formatOrderClock(raw)}';
}

/// Friendly relative time: "Just now", "5m ago", "2h ago",
/// falls back to "21 Sep, 11:32 AM" beyond 24 hours.
String formatOrderTimeAgo(dynamic raw) {
  final t = parseOrderTime(raw);
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return formatOrderDayTime(raw);
}
