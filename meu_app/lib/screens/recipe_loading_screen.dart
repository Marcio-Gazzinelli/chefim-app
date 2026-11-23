part of '../main.dart';

class RecipeLoadingScreen extends StatefulWidget {
  const RecipeLoadingScreen({super.key, required this.products});

  final List<Product> products;

  @override
  State<RecipeLoadingScreen> createState() => _RecipeLoadingScreenState();
}

class _RecipeLoadingScreenState extends State<RecipeLoadingScreen> {
  String _stage = 'Preparando os ingredientes';
  String? _notice;
  String? _error;
  bool _canRetry = false;

  bool get _isActive => mounted && ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isActive) _generate();
    });
  }

  Future<void> _generate() async {
    setState(() {
      _stage = 'Preparando os ingredientes';
      _notice = null;
      _error = null;
      _canRetry = false;
    });

    final recognized = widget.products.where((product) {
      final days = product.days;
      return (days == null || days >= 0) &&
          IngredientNormalizerService.instance.identify(product.name) != null;
    }).toList();

    if (recognized.isEmpty) {
      setState(() {
        _error = 'Nenhum ingrediente selecionado pôde ser usado. '
            'Volte e escolha outros produtos da despensa.';
      });
      return;
    }

    setState(() {
      _stage = 'Buscando referências de receitas';
      if (recognized.length != widget.products.length) {
        _notice = 'Alguns ingredientes selecionados ficaram de fora.';
      }
    });

    try {
      final ranking = await TheMealDbRankingService.instance
          .searchAndRankProducts(products: recognized);

      if (!_isActive) return;
      final references = ranking.where((item) => item.matchedCount > 0);

      if (references.isEmpty) {
        setState(() {
          _error = 'Nenhuma referência compatível foi encontrada. '
              'Tente novamente ou escolha outros ingredientes.';
          _canRetry = true;
        });
        return;
      }

      setState(() => _stage = 'Gerando sua receita com IA');
      final recipe = await AiRecipeService.instance.adaptRecipe(
        products: recognized,
        reference: references.first.recipe,
      );

      if (!_isActive) return;

      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => RecipeResultScreen(recipe: recipe, notice: _notice),
        ),
      );
    } catch (error) {
      debugPrint('Chefim: erro ao gerar receita: $error');
      if (!_isActive) return;
      setState(() {
        _error = 'Não foi possível gerar sua receita. Tente novamente.';
        _canRetry = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: const Text('Gerar receita')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null) ...[
                  const Icon(Icons.soup_kitchen_outlined, size: 52),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _stage,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  Text(error, textAlign: TextAlign.center),
                  if (_canRetry) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _generate,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Voltar aos ingredientes'),
                  ),
                ],
                if (_notice case final notice?) ...[
                  const SizedBox(height: 12),
                  Text(notice, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}