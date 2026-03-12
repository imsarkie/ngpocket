int estimateReadingTimeFromText(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return 1;
  }

  final words = normalized.split(' ').length;
  final minutes = (words / 220).ceil();
  return minutes.clamp(1, 60);
}
