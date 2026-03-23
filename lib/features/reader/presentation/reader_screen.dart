import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/core/models/app_settings.dart';
import 'package:ngpocket/core/services/service_providers.dart';
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
  late final ValueNotifier<double> _progressNotifier;
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_syncProgress);
    _progressNotifier = ValueNotifier(0.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(feedActionsProvider).markRead(widget.article.id, true),
      );
    });
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _scrollController
      ..removeListener(_syncProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ref.watch(readerFontScaleProvider);
    final readerFontFamily = ref.watch(readerFontFamilyProvider);
    final readerTextAlignment = ref.watch(readerTextAlignmentProvider);
    final preparedAsync = ref.watch(
      readerPreparedContentProvider(widget.article),
    );
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
          child: ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, progress, _) => LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
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
      body: preparedAsync.when(
        data: (prepared) => ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            _selectedText == null ? 40 : 112,
          ),
          itemCount: prepared.paragraphs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Center(
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
                        style: _applyReaderFont(
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                height: 1.22,
                              ) ??
                              const TextStyle(fontSize: 30, height: 1.22),
                          readerFontFamily,
                        ),
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
                    ],
                  ),
                ),
              );
            }
            final paragraph = prepared.paragraphs[index - 1];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: _buildParagraph(
                      context,
                      paragraph,
                      fontScale,
                      readerFontFamily,
                      readerTextAlignment,
                      highlights,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to prepare article content.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(
    BuildContext context,
    ReaderParagraph paragraph,
    double fontScale,
    ReaderFontFamily readerFontFamily,
    ReaderTextAlignment readerTextAlignment,
    List<Highlight> highlights,
  ) {
    final parsed = paragraph;
    final bodyStyle = _applyReaderFont(
      Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 17.6 * fontScale,
            height: 1.95,
            letterSpacing: 0.1,
          ) ??
          TextStyle(
            fontSize: 17.6 * fontScale,
            height: 1.95,
            letterSpacing: 0.1,
          ),
      readerFontFamily,
    );

    final headingStyle = _applyReaderFont(
      Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 30 * fontScale,
            height: 1.24,
            fontWeight: FontWeight.w700,
          ) ??
          TextStyle(
            fontSize: 30 * fontScale,
            height: 1.24,
            fontWeight: FontWeight.w700,
          ),
      readerFontFamily,
    );

    final quoteStyle = bodyStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
    );

    final baseStyle = switch (parsed.kind) {
      ReaderParagraphKind.heading => headingStyle,
      ReaderParagraphKind.quote => quoteStyle,
      ReaderParagraphKind.listItem => bodyStyle,
      ReaderParagraphKind.body => bodyStyle,
    };

    final resolvedStyle = baseStyle;
    final paragraphTextAlign = parsed.kind == ReaderParagraphKind.heading
        ? TextAlign.start
        : _resolveTextAlign(readerTextAlignment);

    if (parsed.kind == ReaderParagraphKind.listItem) {
      final bulletColor = Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.9);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '•',
              style: resolvedStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: bulletColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText.rich(
              TextSpan(
                children: _buildSpansForText(
                  context,
                  text: parsed.text,
                  baseStyle: resolvedStyle,
                  highlights: highlights
                      .map((item) => item.snippet)
                      .toList(growable: false),
                ),
              ),
              textAlign: paragraphTextAlign,
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
              style: resolvedStyle,
            ),
          ),
        ],
      );
    }

    final decoratedChild = SelectableText.rich(
      TextSpan(
        children: _buildSpansForText(
          context,
          text: parsed.text,
          baseStyle: resolvedStyle,
          highlights: highlights
              .map((item) => item.snippet)
              .toList(growable: false),
        ),
      ),
      textAlign: paragraphTextAlign,
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
      style: resolvedStyle,
    );

    if (parsed.kind == ReaderParagraphKind.quote) {
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagSheetBody(articleId: widget.article.id),
    );
  }

  void _syncProgress() {
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      if (_progressNotifier.value != 0) {
        _progressNotifier.value = 0;
      }
      return;
    }

    final value = (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
    if ((value - _progressNotifier.value).abs() > 0.01) {
      _progressNotifier.value = value;
    }
  }

  Future<void> _showTypographySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(appSettingsProvider);
            return SingleChildScrollView(
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
                  Text(
                    'Font Family',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ReaderFontFamily.values
                        .map((font) {
                          final selected = settings.readerFontFamily == font;
                          return ChoiceChip(
                            label: Text(
                              _fontLabel(font),
                              style: _applyReaderFont(
                                Theme.of(context).textTheme.labelLarge ??
                                    const TextStyle(),
                                font,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) {
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setReaderFontFamily(font);
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Paragraph Alignment',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ReaderTextAlignment>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ReaderTextAlignment.left,
                        label: Text('Left'),
                        icon: Icon(Icons.format_align_left_rounded),
                      ),
                      ButtonSegment(
                        value: ReaderTextAlignment.justified,
                        label: Text('Justified'),
                        icon: Icon(Icons.format_align_justify_rounded),
                      ),
                    ],
                    selected: {settings.readerTextAlignment},
                    onSelectionChanged: (selection) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setReaderTextAlignment(selection.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Font Size',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Slider(
                    value: settings.readerFontScale,
                    min: 0.85,
                    max: 1.5,
                    divisions: 13,
                    onChanged: (value) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setReaderFontScale(value);
                    },
                  ),
                  Text(
                    'Current scale: ${settings.readerFontScale.toStringAsFixed(2)}x',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  TextAlign _resolveTextAlign(ReaderTextAlignment alignment) {
    return switch (alignment) {
      ReaderTextAlignment.left => TextAlign.start,
      ReaderTextAlignment.justified => TextAlign.justify,
    };
  }

  String _fontLabel(ReaderFontFamily font) {
    return switch (font) {
      ReaderFontFamily.sourceSerif => 'Source Serif',
      ReaderFontFamily.dmSans => 'DM Sans',
      ReaderFontFamily.playfair => 'Playfair',
    };
  }

  TextStyle _applyReaderFont(TextStyle style, ReaderFontFamily font) {
    return switch (font) {
      ReaderFontFamily.sourceSerif => GoogleFonts.sourceSerif4(
        textStyle: style,
      ),
      ReaderFontFamily.dmSans => GoogleFonts.dmSans(textStyle: style),
      ReaderFontFamily.playfair => GoogleFonts.playfairDisplay(
        textStyle: style,
      ),
    };
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

class _TagSheetBody extends ConsumerStatefulWidget {
  const _TagSheetBody({required this.articleId});

  final int articleId;

  @override
  ConsumerState<_TagSheetBody> createState() => _TagSheetBodyState();
}

class _TagSheetBodyState extends ConsumerState<_TagSheetBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(readerActionsProvider);
    final articleTags =
        ref.watch(articleTagsProvider(widget.articleId)).valueOrNull ??
        const <String>[];
    final suggestions =
        ref.watch(tagSuggestionsProvider).valueOrNull ?? const <String>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tags', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Add a tag',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) async {
                        await actions.addTag(
                          articleId: widget.articleId,
                          tag: value,
                        );
                        _controller.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await actions.addTag(
                        articleId: widget.articleId,
                        tag: _controller.text,
                      );
                      _controller.clear();
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
                                articleId: widget.articleId,
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
                                articleId: widget.articleId,
                                tag: tag,
                              ),
                            );
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}
