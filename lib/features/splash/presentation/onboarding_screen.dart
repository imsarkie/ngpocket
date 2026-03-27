import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kOnboardingDoneKey = 'onboarding.completed_v1';

/// Shows onboarding on first launch, then never again.
Future<bool> isOnboardingNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kOnboardingDoneKey) ?? false);
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
}

// ─── Data ────────────────────────────────────────────────────────────────────

class _OnboardPage {
  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.body,
    required this.accentColor,
  });
  final String emoji;
  final String title;
  final String body;
  final Color accentColor;
}

const List<_OnboardPage> _pages = [
  _OnboardPage(
    emoji: '📖',
    title: 'Your personal reading inbox',
    body:
        'Save any article from the web with one tap. Reader stores everything offline so you can read at your own pace — no clutter, no distractions.',
    accentColor: Color(0xFFD97D55),
  ),
  _OnboardPage(
    emoji: '🗞️',
    title: 'Follow RSS feeds you love',
    body:
        'Subscribe to any website or blog. Reader fetches fresh stories in the background and surfaces them straight to your inbox every morning.',
    accentColor: Color(0xFF6FA4AF),
  ),
  _OnboardPage(
    emoji: '🃏',
    title: 'Swipe through stories',
    body:
        'Swipe right to save an article for later. Swipe left to dismiss. Power through your feed the same way you scroll a deck of cards — fast and effortless.',
    accentColor: Color(0xFFB8C4A9),
  ),
  _OnboardPage(
    emoji: '✏️',
    title: 'Highlight & remember',
    body:
        'Long-press any paragraph in the reader to highlight it. All your highlights are saved to the Library, ready to revisit or share whenever you like.',
    accentColor: Color(0xFFD4A373),
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _advance() {
    if (_isLastPage) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0E3),
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLastPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _isLastPage ? null : _finish,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF6B665E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // ── Page carousel ────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    _OnboardPageView(page: _pages[index]),
              ),
            ),

            // ── Indicator row ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? page.accentColor
                        : const Color(0xFFC5B8A5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── CTA button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: page.accentColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: page.accentColor.withValues(alpha: .35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _advance,
                      child: Center(
                        child: Text(
                          _isLastPage ? 'Get started' : 'Continue',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Single page ─────────────────────────────────────────────────────────────

class _OnboardPageView extends StatelessWidget {
  const _OnboardPageView({required this.page});

  final _OnboardPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: page.accentColor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 70),
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSerif4(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C2925),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),

          // Body
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 15.5,
              color: const Color(0xFF6B665E),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
