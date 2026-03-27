import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareHighlightDialog extends StatefulWidget {
  const ShareHighlightDialog({required this.item, super.key});

  final ReaderHighlight item;

  @override
  State<ShareHighlightDialog> createState() => _ShareHighlightDialogState();
}

class _ShareHighlightDialogState extends State<ShareHighlightDialog> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isGenerating = false;

  Future<void> _captureAndShare() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('RepaintBoundary not found');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception('Failed to generate image bytes.');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/quote_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      
      final authorName = widget.item.articleAuthor ?? widget.item.articleSource ?? 'Reader';
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'A highlight via Reader — $authorName',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorLabel =
        widget.item.articleAuthor ?? widget.item.articleSource ?? 'Reader User';
    final hasBackground = widget.item.articleImage != null;

    final Widget previewCard = AspectRatio(
      aspectRatio: 0.8,
      child: RepaintBoundary(
        key: _globalKey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasBackground)
                CachedNetworkImage(
                  imageUrl: widget.item.articleImage!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: AppTheme.mistBlue,
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.clay, AppTheme.mistBlue],
                    ),
                  ),
                ),
              // Strong blur
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.40),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      color: AppTheme.beige,
                      size: 56,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.item.highlight.snippet,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '— $authorLabel',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          previewCard,
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _captureAndShare,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.clay,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  _isGenerating ? 'Exporting...' : 'Share Image',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
