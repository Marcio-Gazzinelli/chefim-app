part of '../main.dart';

const Color _chefimSplashGreen = Color(0xFF3DAA37);

const TextStyle _chefimSplashNameStyle = TextStyle(
  color: Colors.white,
  fontSize: 48,
  height: 1.2,
  fontWeight: FontWeight.w900,
  letterSpacing: -1.5,
);

const TextStyle _chefimSplashSubtitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.2,
);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _symbolOpacity;
  late final Animation<double> _symbolScale;
  late final Animation<double> _symbolMovement;
  late final Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _symbolOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.18, curve: Curves.easeOut),
    );

    _symbolScale = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.30, curve: Curves.easeOutBack),
      ),
    );

    _symbolMovement = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.42, curve: Curves.easeInOutCubic),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.87, 1, curve: Curves.easeOut),
    );

    _startOpening();
  }

  Future<void> _startOpening() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ChefimShell();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chefimSplashGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoWidth = constraints.maxWidth > 330
                    ? 330.0
                    : constraints.maxWidth;

                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: logoWidth,
                          height: 100,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: Offset(
                                  -logoWidth * 0.28 * _symbolMovement.value,
                                  0,
                                ),
                                child: Opacity(
                                  opacity: _symbolOpacity.value,
                                  child: Transform.scale(
                                    scale: _symbolScale.value,
                                    child: const Icon(
                                      Icons.soup_kitchen_rounded,
                                      color: Colors.white,
                                      size: 72,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: logoWidth * 0.34,
                                top: 17,
                                child: _ChefimSplashWord.animated(
                                  controller: _controller,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Transform.translate(
                          offset: Offset(0, 12 * (1 - _subtitleOpacity.value)),
                          child: Opacity(
                            opacity: _subtitleOpacity.value,
                            child: const Text(
                              'Seu Companheiro na Cozinha',
                              textAlign: TextAlign.center,
                              style: _chefimSplashSubtitleStyle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Monta a palavra "Chefim" letra por letra.
///
/// Cada letra aparece em um instante diferente, com movimento,
/// rotação e aumento de escala.
class _ChefimSplashWord extends StatelessWidget {
  const _ChefimSplashWord.animated({required this.controller});

  const _ChefimSplashWord.finished() : controller = null;

  final AnimationController? controller;

  double _letterProgress(int index) {
    if (controller == null) {
      return 1;
    }

    const firstLetterStart = 0.34;
    const delayBetweenLetters = 0.075;
    const letterDuration = 0.24;

    final start = firstLetterStart + (index * delayBetweenLetters);
    final end = start + letterDuration;

    return ((controller!.value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    const word = 'Chefim';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(word.length, (index) {
        final progress = _letterProgress(index);

        final opacity = Curves.easeOut.transform(progress);

        final bounceProgress = Curves.easeOutBack.transform(progress);

        final horizontalDirection = index.isEven ? -1.0 : 1.0;

        final horizontalMovement =
            horizontalDirection * 9 * (1 - bounceProgress);

        final verticalMovement = 22 * (1 - bounceProgress);

        final rotation = horizontalDirection * 0.10 * (1 - progress);

        final scale = 0.45 + (0.55 * bounceProgress);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(horizontalMovement, verticalMovement),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  word[index],
                  maxLines: 1,
                  style: _chefimSplashNameStyle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Tela apresentada caso o Chefim ainda esteja carregando os dados
/// depois que a animação inicial terminar.
class _ChefimSplashFinished extends StatelessWidget {
  const _ChefimSplashFinished();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chefimSplashGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoWidth = constraints.maxWidth > 330
                    ? 330.0
                    : constraints.maxWidth;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: logoWidth,
                      height: 100,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(-logoWidth * 0.28, 0),
                            child: const Icon(
                              Icons.soup_kitchen_rounded,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                          Positioned(
                            left: logoWidth * 0.34,
                            top: 17,
                            child: const _ChefimSplashWord.finished(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Seu Companheiro na Cozinha',
                      textAlign: TextAlign.center,
                      style: _chefimSplashSubtitleStyle,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
