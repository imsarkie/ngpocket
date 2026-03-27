import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/network/network_client.dart';
import 'package:reader/core/services/article_parser_service.dart';
import 'package:reader/core/services/haptic_service.dart';
import 'package:reader/core/services/rss_service.dart';
import 'package:reader/core/services/share_intent_service.dart';

final rssServiceProvider = Provider<RssService>((ref) {
  return RssService(ref.watch(dioProvider));
});

final articleParserServiceProvider = Provider<ArticleParserService>((ref) {
  return ArticleParserService(ref.watch(dioProvider));
});

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  return ShareIntentService();
});

final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService();
});
