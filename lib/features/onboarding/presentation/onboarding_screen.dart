import 'package:flutter/material.dart';

class _OnboardingPage {
  const _OnboardingPage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _OnboardingPage(
    icon: Icons.visibility_outlined,
    title: 'Kirain cukup, taunya boncos.',
    body:
        'KIRAIN bantu kamu mikir dulu sebelum belanja, bukan cuma nyatet '
        'setelah duitnya abis.',
  ),
  _OnboardingPage(
    icon: Icons.rule_outlined,
    title: 'Bedain Wajib vs Keinginan',
    body:
        'Tiap transaksi, tinggal toggle: ini emang kebutuhan, atau cuma '
        'keinginan? Biar kamu sadar ke mana aja duit kamu pergi.',
  ),
  _OnboardingPage(
    icon: Icons.edit_note_outlined,
    title: 'Catat gampang, 2-3 tap doang',
    body: 'Gak perlu ribet. Yuk mulai atur keuangan kamu bareng KIRAIN.',
  ),
];

/// Max 3 slides + Skip, per CLAUDE.md's onboarding requirement. Shown once
/// (gated by [OnboardingGate]) before the user ever hits sign-in.
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
    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 96, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLastPage ? 'Mulai' : 'Lanjut'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
