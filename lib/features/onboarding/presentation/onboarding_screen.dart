import 'package:flutter/material.dart';

import '../../../core/theme/kirain_colors.dart';
import '../../../core/widgets/kaget_eyebrows.dart';

class _OnboardingPage {
  const _OnboardingPage({required this.title, required this.body});

  final String title;
  final String body;
}

const _pages = [
  _OnboardingPage(
    title: 'Kirain cukup, taunya boncos.',
    body:
        'KIRAIN bantu kamu mikir dulu sebelum belanja, bukan cuma nyatet '
        'setelah duitnya abis.',
  ),
  _OnboardingPage(
    title: 'Bedain Wajib vs Keinginan',
    body:
        'Tiap transaksi, tinggal toggle: ini emang kebutuhan, atau cuma '
        'keinginan? Biar kamu sadar ke mana aja duit kamu pergi.',
  ),
  _OnboardingPage(
    title: 'Catat gampang, 2-3 tap doang',
    body: 'Gak perlu ribet. Yuk mulai atur keuangan kamu bareng KIRAIN.',
  ),
];

/// Max 3 slides + always-available "Lewati", per CLAUDE.md's onboarding
/// requirement. Shown once (gated by [OnboardingGate]) before the user ever
/// hits sign-in — [onDone] marks the flag seen and lets the gate's own
/// child (the router) route to Sign In or Home, whichever the auth state
/// calls for; this screen doesn't need to know which.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _page == _pages.length - 1;

  void _next() {
    if (_isLastPage) {
      widget.onDone();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mintFill = theme.extension<KirainColors>()?.mint ?? theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(onPressed: widget.onDone, child: const Text('Lewati')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  return _OnboardingSlide(page: _pages[index], controller: _controller, index: index);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _page ? mintFill : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(_isLastPage ? 'Mulai Sekarang' : 'Lanjut', key: ValueKey(_isLastPage)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One slide's content, cross-fading (+ subtle scale) as it slides in/out
/// with the page's own swipe/programmatic scroll — CLAUDE.md's "Prinsip
/// Animasi & Transisi" calls for fade or fade+slide over an instant cut,
/// and [PageView] alone only gives the slide, not the fade.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.page, required this.controller, required this.index});

  final _OnboardingPage page;
  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final mintStrong = kirainColors?.mintStrong ?? theme.colorScheme.primary;
    final coralStrong = kirainColors?.coralStrong ?? theme.colorScheme.secondary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 72,
            child: KagetEyebrows(leftColor: mintStrong, rightColor: coralStrong, strokeWidth: 10),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = controller.hasClients ? (controller.page ?? index.toDouble()) : index.toDouble();
        final delta = (page - index).clamp(-1.0, 1.0);
        final opacity = 1 - delta.abs();
        final scale = 1 - (delta.abs() * 0.08);
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      },
      child: content,
    );
  }
}
