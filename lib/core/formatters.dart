String _two(int n) => n.toString().padLeft(2, '0');

/// 09/11 14:05
String formatDayTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';

/// 09/11/2026 às 14:05
String formatFullDateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} às ${_two(d.hour)}:${_two(d.minute)}';

/// "agora mesmo", "há 5 min", "há 2 h", "há 3 dias".
String formatAgo(DateTime d, DateTime now) {
  final diff = now.difference(d);
  if (diff.inSeconds < 60) return 'agora mesmo';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  final days = diff.inDays;
  return days == 1 ? 'há 1 dia' : 'há $days dias';
}
