import 'dart:io';

import 'package:reader/core/parsing/rss_content_parser.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedImport {
  const SharedImport({this.articleUrl, this.rssDocument, this.fileName});

  final String? articleUrl;
  final String? rssDocument;
  final String? fileName;
}

class ShareIntentService {
  Stream<SharedImport> sharedImportStream() {
    return ReceiveSharingIntent.instance
        .getMediaStream()
        .expand((items) => items)
        .asyncMap(_parseSharedMedia)
        .where((payload) => payload != null)
        .cast<SharedImport>();
  }

  Stream<String> sharedUrlStream() {
    return sharedImportStream()
        .map((payload) => payload.articleUrl)
        .where((url) => url != null)
        .cast<String>();
  }

  Future<SharedImport?> getInitialSharedImport() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    await ReceiveSharingIntent.instance.reset();

    for (final media in initial) {
      final parsed = await _parseSharedMedia(media);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  Future<String?> getInitialSharedUrl() async {
    final sharedImport = await getInitialSharedImport();
    return sharedImport?.articleUrl;
  }

  Future<SharedImport?> _parseSharedMedia(SharedMediaFile media) async {
    final articleUrl = _normalizeUrl(media.path);
    if (articleUrl != null) {
      return SharedImport(articleUrl: articleUrl);
    }

    final filePath = _normalizeFilePath(media.path);
    if (filePath == null) {
      return null;
    }

    if (!_looksLikeRssFile(filePath)) {
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    if (!looksLikeRssDocument(content)) {
      return null;
    }

    return SharedImport(rssDocument: content, fileName: p.basename(filePath));
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

  String? _normalizeFilePath(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.startsWith('file://')) {
      try {
        return Uri.parse(trimmed).toFilePath();
      } catch (_) {
        return null;
      }
    }

    if (trimmed.startsWith('/')) {
      return trimmed;
    }

    return null;
  }

  bool _looksLikeRssFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.rss') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.atom');
  }
}
