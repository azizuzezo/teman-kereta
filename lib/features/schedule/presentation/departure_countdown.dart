/// Short countdown label for a departure that is [remaining] away:
/// "Sekarang" under a minute, "12 mnt" under an hour, then "1 j 5 mnt".
String formatCountdown(Duration remaining) {
  if (remaining.inSeconds < 60) {
    return 'Sekarang';
  }
  final minutes = remaining.inMinutes;
  if (minutes < 60) {
    return '$minutes mnt';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours j' : '$hours j $rest mnt';
}
