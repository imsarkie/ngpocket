import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareIntentService {
  Stream<String> sharedUrlStream() {
    return ReceiveSharingIntent.instance
        .getMediaStream()
        .expand((items) => items)
        .map((media) => _normalizeUrl(media.path))
        .where((url) => url != null)
        .cast<String>();
  }

  Future<String?> getInitialSharedUrl() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    await ReceiveSharingIntent.instance.reset();

    for (final media in initial) {
      final normalized = _normalizeUrl(media.path);
      if (normalized != null) {
        return normalized;
      }
    }

    return null;
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    return trimmed;
  }
}
