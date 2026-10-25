part of '../main.dart';

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
  late final Animation<double> _nameReveal;
  late final Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );

    _symbolOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.20, curve: Curves.easeOut),
    );

    _symbolScale = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.32, curve: Curves.easeOutBack),
      ),
    );

    _symbolMovement = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.58, curve: Curves.easeInOutCubic),
    );

    _nameReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.78, curve: Curves.easeOutCubic),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1, curve: Curves.easeOut),
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
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChefimShell(),
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
    const splashGreen = Color(0xFF3DAA37);

    return Scaffold(
      backgroundColor: splashGreen,
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
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _nameReveal.value,
                                    child: const Text(
                                      'Chefim',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        height: 1.2,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                  ),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
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
