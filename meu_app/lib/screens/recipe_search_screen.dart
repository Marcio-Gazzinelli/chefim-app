part of '../main.dart';

class ScaledRecipesPage extends StatefulWidget {
  const ScaledRecipesPage({super.key, required this.userId});

  final int? userId;

  @override
  State<ScaledRecipesPage> createState() => _ScaledRecipesPageState();
}

class _ScaledRecipesPageState extends State<ScaledRecipesPage> {
  final searchController = TextEditingController();

  List<SavedRecipe> _recipes = const [];
  List<Product> _pantryProducts = const [];

  final Set<int> _deletingRecipeIds = <int>{};

  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final recipes = await DatabaseService.instance.getSavedRecipes(
        userId: widget.userId,
      );

      final pantryProducts = await DatabaseService.instance.getProducts(
        userId: widget.userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recipes = recipes;
        _pantryProducts = pantryProducts;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Chefim: erro ao carregar receitas salvas: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar as receitas salvas.';
      });
    }
  }

  String _normalize(String value) {
    return IngredientNormalizerService.instance.normalizeText(value);
  }

  List<SavedRecipe> get _filteredRecipes {
    final terms = _normalize(_query)
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList(growable: false);

    if (terms.isEmpty) {
      return _recipes;
    }

    return _recipes
        .where((saved) {
          final recipe = saved.recipe;

          final searchableText = _normalize(
            [
              recipe.name,
              ...recipe.ingredients.map((ingredient) => ingredient.name),
            ].join(' '),
          );

          return terms.every(searchableText.contains);
        })
        .toList(growable: false);
  }

  Future<void> _openRecipe(SavedRecipe saved) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultScreen(
          recipe: saved.recipe,
          userId: widget.userId,
          pantryProducts: _pantryProducts,
          savedRecipeId: saved.id,
        ),
      ),
    );
  }

  Future<void> _deleteRecipe(SavedRecipe saved) async {
    final recipeId = saved.id;

    if (recipeId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Não foi possível identificar a receita.'),
          ),
        );

      return;
    }

    if (_deletingRecipeIds.contains(recipeId)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir receita?'),
          content: Text(
            'A receita “${saved.recipe.name}” será removida '
            'das receitas salvas.\n\n'
            'Essa ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _deletingRecipeIds.add(recipeId);
    });

    try {
      final deletedRows = await DatabaseService.instance.deleteSavedRecipe(
        recipeId,
      );

      if (!mounted) {
        return;
      }

      if (deletedRows != 1) {
        throw StateError('A receita não foi encontrada no banco de dados.');
      }

      setState(() {
        _recipes = _recipes
            .where((recipe) => recipe.id != recipeId)
            .toList(growable: false);

        _deletingRecipeIds.remove(recipeId);
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Receita excluída.')));
    } catch (error) {
      debugPrint('Chefim: erro ao excluir receita salva: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _deletingRecipeIds.remove(recipeId);
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir a receita.')),
        );
    }
  }

  String _recipeDetails(AiGeneratedRecipe recipe) {
    final parts = <String>[
      '${recipe.servings} '
          '${recipe.servings == 1 ? 'porção' : 'porções'}',
      '${recipe.ingredients.length} ingredientes',
    ];

    final calories = recipe.estimatedCaloriesPerServing;

    if (calories != null) {
      parts.add('~$calories kcal/porção');
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: scroll([
          topbar('Receitas salvas', back: () => Navigator.pop(context)),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: input('Pesquisar por receita ou ingrediente').copyWith(
              prefixIcon: Icon(Icons.search, color: darkGreen),
              suffixIcon: hasQuery
                  ? IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        searchController.clear();

                        setState(() {
                          _query = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error case final message?) ...[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadRecipes,
              child: const Text('Tentar novamente'),
            ),
          ] else if (recipes.isEmpty)
            panel(
              Column(
                children: [
                  Icon(
                    hasQuery
                        ? Icons.search_off_outlined
                        : Icons.bookmark_border,
                    size: 42,
                    color: muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasQuery
                        ? 'Nenhuma receita encontrada.'
                        : 'Você ainda não salvou receitas.',
                    textAlign: TextAlign.center,
                    style: type(14, bold: true),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasQuery
                        ? 'Tente pesquisar outro nome ou ingrediente.'
                        : 'Gere uma receita e toque em '
                              '“Salvar receita”.',
                    textAlign: TextAlign.center,
                    style: type(12, color: muted),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              '${recipes.length} '
              '${recipes.length == 1 ? 'receita' : 'receitas'}',
              style: type(12, color: muted),
            ),
            const SizedBox(height: 8),
            for (final saved in recipes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: panel(
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _openRecipe(saved),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              children: [
                                badge(
                                  Icons.restaurant_menu,
                                  softGreen,
                                  darkGreen,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        saved.recipe.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: type(14, bold: true),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _recipeDetails(saved.recipe),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: type(11, color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right, color: muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: 'Excluir receita',
                        onPressed:
                            saved.id == null ||
                                _deletingRecipeIds.contains(saved.id)
                            ? null
                            : () => _deleteRecipe(saved),
                        icon: _deletingRecipeIds.contains(saved.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ]),
      ),
    );
  }
}
