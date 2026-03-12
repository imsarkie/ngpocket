import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';
import 'package:ngpocket/features/feed/providers/feed_provider.dart';
import 'package:ngpocket/features/reader/providers/reader_provider.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.article});

  final Article article;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final ScrollController _scrollController;
  late final String _plainText;
  double _progress = 0;
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_syncProgress);

    final content = widget.article.content.isEmpty
        ? (widget.article.description ?? widget.article.title)
        : widget.article.content;
    // Only run through htmlToPlainText if content is actually HTML.
    // Parsed/structured content already uses markdown-style markers (> , ## )
    // that would be destroyed by the HTML parser.
    _plainText = content.contains('<') ? htmlToPlainText(content) : content;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(feedActionsProvider).markRead(widget.article.id, true),
      );
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(readerFontScaleProvider);
    final paragraphs = _paragraphs(_plainText);
    final highlightsAsync = ref.watch(
      articleHighlightsProvider(widget.article.id),
    );
    final highlights = highlightsAsync.valueOrNull ?? const <Highlight>[];
    final highlightCount = highlights.length;
    final tagsAsync = ref.watch(articleTagsProvider(widget.article.id));
    final tags = tagsAsync.valueOrNull ?? const <String>[];
    final canHighlight = _selectedText?.trim().isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reader'),
        actions: [
          IconButton(
            tooltip: 'Re-parse article',
            icon: const Icon(Icons.sync_rounded),
            onPressed: _reparseCurrentArticle,
          ),
          IconButton(
            tooltip: 'Open original in browser',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: _openOriginalInBrowser,
          ),
          IconButton(
            tooltip: 'Tags',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () => _showTagsSheet(context),
          ),
          IconButton(
            tooltip: 'Adjust typography',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => _showTypographySheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 2,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      bottomSheet: _selectedText == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selection ready • $highlightCount highlights',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedText = null),
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: canHighlight
                          ? () => _saveHighlight(context, _selectedText!)
                          : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Highlight'),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          _selectedText == null ? 40 : 112,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.article.image != null &&
                      widget.article.image!.isNotEmpty)
                    Hero(
                      tag: 'article-image-${widget.article.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: CachedNetworkImage(
                          imageUrl: widget.article.image!,
                          fit: BoxFit.cover,
                          height: 220,
                        ),
                      ),
                    ),
                  if (widget.article.image != null &&
                      widget.article.image!.isNotEmpty)
                    const SizedBox(height: 24),
                  Text(
                    widget.article.title,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(height: 1.22),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (widget.article.author != null &&
                          widget.article.author!.isNotEmpty)
                        _Meta(text: widget.article.author!),
                      _Meta(text: '${widget.article.readingTime} min read'),
                      if (widget.article.source != null &&
                          widget.article.source!.isNotEmpty)
                        _Meta(text: widget.article.source!),
                      ...tags.map((tag) => _Meta(text: '#$tag')),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ...paragraphs.map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: _buildParagraph(
                        context,
                        paragraph,
                        fontScale,
                        highlights,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(
    BuildContext context,
    String rawParagraph,
    double fontScale,
    List<Highlight> highlights,
  ) {
    final parsed = _parseParagraph(rawParagraph);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 17.6 * fontScale,
      height: 1.95,
      letterSpacing: 0.1,
    );

    final headingStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: 30 * fontScale,
      height: 1.24,
      fontWeight: FontWeight.w700,
    );

    final quoteStyle = bodyStyle?.copyWith(
      fontStyle: FontStyle.italic,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
    );

    final baseStyle = switch (parsed.kind) {
      _ParagraphKind.heading => headingStyle,
      _ParagraphKind.quote => quoteStyle,
      _ParagraphKind.listItem => bodyStyle,
      _ParagraphKind.body => bodyStyle,
    };

    final decoratedChild = SelectableText.rich(
      TextSpan(
        children: _buildSpansForText(
          context,
          text: parsed.text,
          baseStyle: baseStyle ?? const TextStyle(),
          highlights: highlights
              .map((item) => item.snippet)
              .toList(growable: false),
        ),
      ),
      onSelectionChanged: (selection, cause) {
        if (selection.isCollapsed || parsed.text.isEmpty) {
          return;
        }

        final start = selection.start.clamp(0, parsed.text.length);
        final end = selection.end.clamp(0, parsed.text.length);
        if (start >= end) {
          return;
        }

        final selected = parsed.text.substring(start, end).trim();
        if (selected.isEmpty) {
          return;
        }

        if (selected != _selectedText) {
          setState(() => _selectedText = selected);
        }
      },
      style: baseStyle,
    );

    if (parsed.kind == _ParagraphKind.quote) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 0, 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.45),
              width: 3,
            ),
          ),
        ),
        child: decoratedChild,
      );
    }

    return decoratedChild;
  }

  _ParsedParagraph _parseParagraph(String input) {
    if (input.startsWith('## ')) {
      return _ParsedParagraph(
        _ParagraphKind.heading,
        input.substring(3).trim(),
      );
    }

    if (input.startsWith('> ')) {
      return _ParsedParagraph(_ParagraphKind.quote, input.substring(2).trim());
    }

    if (input.startsWith('- ')) {
      return _ParsedParagraph(
        _ParagraphKind.listItem,
        '• ${input.substring(2).trim()}',
      );
    }

    return _ParsedParagraph(_ParagraphKind.body, input);
  }

  List<InlineSpan> _buildSpansForText(
    BuildContext context, {
    required String text,
    required TextStyle baseStyle,
    required List<String> highlights,
  }) {
    final highlightRanges = _findHighlightRanges(text, highlights);
    final spans = <InlineSpan>[];
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0x996A5620)
        : const Color(0xFFF8ECA8);

    var cursor = 0;
    for (final range in highlightRanges) {
      if (cursor < range.start) {
        _appendLinkifiedSpans(
          context,
          spans,
          text.substring(cursor, range.start),
          baseStyle,
        );
      }

      _appendLinkifiedSpans(
        context,
        spans,
        text.substring(range.start, range.end),
        baseStyle.copyWith(backgroundColor: highlightColor),
      );
      cursor = range.end;
    }

    if (cursor < text.length) {
      _appendLinkifiedSpans(context, spans, text.substring(cursor), baseStyle);
    }

    return spans;
  }

  List<_TextRange> _findHighlightRanges(
    String paragraph,
    List<String> snippets,
  ) {
    final ranges = <_TextRange>[];
    final paragraphLower = paragraph.toLowerCase();

    for (final snippet in snippets) {
      final normalized = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) {
        continue;
      }

      final needle = normalized.toLowerCase();
      var startIndex = 0;
      while (true) {
        final index = paragraphLower.indexOf(needle, startIndex);
        if (index < 0) {
          break;
        }

        ranges.add(_TextRange(index, index + needle.length));
        startIndex = index + needle.length;
      }
    }

    if (ranges.isEmpty) {
      return ranges;
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_TextRange>[ranges.first];

    for (final range in ranges.skip(1)) {
      final last = merged.last;
      if (range.start <= last.end) {
        merged[merged.length - 1] = _TextRange(
          last.start,
          math.max(last.end, range.end),
        );
      } else {
        merged.add(range);
      }
    }

    return merged;
  }

  void _appendLinkifiedSpans(
    BuildContext context,
    List<InlineSpan> spans,
    String segment,
    TextStyle style,
  ) {
    if (segment.isEmpty) {
      return;
    }

    final markdownLink = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');
    var cursor = 0;

    for (final match in markdownLink.allMatches(segment)) {
      if (match.start > cursor) {
        _appendRawUrlSpans(
          context,
          spans,
          segment.substring(cursor, match.start),
          style,
        );
      }

      final label = match.group(1)!;
      final url = match.group(2)!;
      spans.add(
        TextSpan(
          text: label,
          style: style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.primary,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
        ),
      );

      cursor = match.end;
    }

    if (cursor < segment.length) {
      _appendRawUrlSpans(context, spans, segment.substring(cursor), style);
    }
  }

  void _appendRawUrlSpans(
    BuildContext context,
    List<InlineSpan> spans,
    String segment,
    TextStyle style,
  ) {
    if (segment.isEmpty) {
      return;
    }

    final regex = RegExp(r'https?://[^\s)]+', caseSensitive: false);
    var cursor = 0;

    for (final match in regex.allMatches(segment)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: segment.substring(cursor, match.start), style: style),
        );
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.primary,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
        ),
      );

      cursor = match.end;
    }

    if (cursor < segment.length) {
      spans.add(TextSpan(text: segment.substring(cursor), style: style));
    }
  }

  Future<void> _openOriginalInBrowser() {
    return _openUrl(widget.article.url, external: true);
  }

  Future<void> _openUrl(String rawUrl, {bool external = false}) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid link.')));
      }
      return;
    }

    ref.read(hapticServiceProvider).selection();

    try {
      final didLaunch = await launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );

      if (!didLaunch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: ${uri.toString()}')),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        if (error.code == 'channel-error') {
          await Clipboard.setData(ClipboardData(text: uri.toString()));
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Browser plugin not ready. Stop and rerun the app once. Link copied.',
              ),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open link: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Browser plugin missing in current run. Stop and rerun app. Link copied.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: ${uri.toString()}')),
        );
      }
    }
  }

  Future<void> _reparseCurrentArticle() async {
    ref.read(hapticServiceProvider).selection();

    try {
      await ref
          .read(feedActionsProvider)
          .ingestSharedUrl(widget.article.url, markSaved: widget.article.saved);

      final refreshed = await ref
          .read(appDatabaseProvider)
          .findArticleByUrl(widget.article.url);

      if (!mounted) {
        return;
      }

      if (refreshed == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Re-parse completed.')));
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReaderScreen(article: refreshed)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to re-parse this article.')),
      );
    }
  }

  Future<void> _showTagsSheet(BuildContext context) async {
    final controller = TextEditingController();
    final actions = ref.read(readerActionsProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Consumer(
            builder: (context, ref, child) {
              final articleTags =
                  ref
                      .watch(articleTagsProvider(widget.article.id))
                      .valueOrNull ??
                  const <String>[];
              final suggestions =
                  ref.watch(tagSuggestionsProvider).valueOrNull ??
                  const <String>[];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tags', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'Add a tag',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) async {
                            await actions.addTag(
                              articleId: widget.article.id,
                              tag: value,
                            );
                            controller.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          await actions.addTag(
                            articleId: widget.article.id,
                            tag: controller.text,
                          );
                          controller.clear();
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (articleTags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: articleTags
                          .map(
                            (tag) => InputChip(
                              label: Text(tag),
                              onDeleted: () {
                                unawaited(
                                  actions.removeTag(
                                    articleId: widget.article.id,
                                    tag: tag,
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(growable: false),
                    )
                  else
                    Text(
                      'No tags yet for this article.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 14),
                  if (suggestions.isNotEmpty)
                    Text(
                      'Suggestions',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  if (suggestions.isNotEmpty) const SizedBox(height: 8),
                  if (suggestions.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions
                          .where((tag) => !articleTags.contains(tag))
                          .take(12)
                          .map(
                            (tag) => ActionChip(
                              label: Text(tag),
                              onPressed: () {
                                unawaited(
                                  actions.addTag(
                                    articleId: widget.article.id,
                                    tag: tag,
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              );
            },
          ),
        );
      },
    );

    controller.dispose();
  }

  List<String> _paragraphs(String plainText) {
    final repaired = plainText
        .replaceAll(RegExp(r'(?<!\n)\s##\s+'), '\n\n## ')
        .replaceAll(RegExp(r'(?<!\n)\s>\s+'), '\n\n> ');

    final blocks = repaired
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (blocks.isEmpty) {
      return blocks;
    }

    final titleNormalized = widget.article.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    return blocks
        .where((block) {
          if (RegExp(r'^[\-\u2013\u2014\s]{1,4}$').hasMatch(block)) {
            return false;
          }

          if (RegExp(
            r'^(https?://|www\.)',
            caseSensitive: false,
          ).hasMatch(block)) {
            return false;
          }

          if (RegExp(r'^\[[^\]]+\]\(https?://[^\s)]+\)$').hasMatch(block)) {
            return false;
          }

          final lower = block.toLowerCase();
          if (lower.startsWith('by ') || lower.startsWith('published ')) {
            return false;
          }

          // Filter "— Published ... — URL —" style footer lines.
          final stripped = block
              .replaceAll(RegExp(r'[\u2014\u2013\-]+'), '')
              .trim()
              .toLowerCase();
          if (stripped.startsWith('published') &&
              RegExp(r'https?://', caseSensitive: false).hasMatch(block)) {
            return false;
          }

          // Deduplicate: body text that exactly matches the article title.
          final blockNormalized =
              (block.startsWith('## ') ? block.substring(3) : block)
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
                  .trim();
          if (blockNormalized == titleNormalized) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  void _syncProgress() {
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      if (_progress != 0) {
        setState(() => _progress = 0);
      }
      return;
    }

    final value = (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
    if ((value - _progress).abs() > 0.01) {
      setState(() => _progress = value);
    }
  }

  Future<void> _showTypographySheet(BuildContext context) async {
    final current = ref.read(readerFontScaleProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reader Typography',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Font Size', style: Theme.of(context).textTheme.labelLarge),
              Consumer(
                builder: (context, ref, child) {
                  final scale = ref.watch(readerFontScaleProvider);
                  return Slider(
                    value: scale,
                    min: 0.85,
                    max: 1.5,
                    divisions: 13,
                    onChanged: (value) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setReaderFontScale(value);
                    },
                  );
                },
              ),
              Text(
                'Current scale: ${current.toStringAsFixed(2)}x',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveHighlight(BuildContext context, String selectedText) async {
    final result = await ref
        .read(readerActionsProvider)
        .saveHighlight(articleId: widget.article.id, text: selectedText);

    if (!context.mounted) {
      return;
    }

    switch (result) {
      case HighlightSaveResult.saved:
        setState(() => _selectedText = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Highlight saved.')));
      case HighlightSaveResult.emptySelection:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a longer snippet to highlight.'),
          ),
        );
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _ParsedParagraph {
  const _ParsedParagraph(this.kind, this.text);

  final _ParagraphKind kind;
  final String text;
}

enum _ParagraphKind { heading, quote, listItem, body }

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}
