part of '../main.dart';

class TheMealDbResultsPage extends StatefulWidget {
  const TheMealDbResultsPage({super.key, required this.products});

  final List<Product> products;

  @override
  State<TheMealDbResultsPage> createState() => _TheMealDbResultsPageState();
}

class _TheMealDbResultsPageState extends State<TheMealDbResultsPage> {
  final Set<int> _selected = {};

  bool _loading = false;
  String? _error;
  AiGeneratedRecipe? _recipe;

  List<Product> get _availableProducts {
    return widget.products
        .where((product) {
          final days = product.days;

          return product.quantity.isFinite &&
              product.quantity > 0 &&
              (days == null || days >= 0);
        })
        .toList(growable: false);
  }

  Future<void> _generateExpiryRecipe() async {
    if (_loading) return;

    final available = _availableProducts;
    final normalizer = IngredientNormalizerService.instance;

    // Considera somente produtos reconhecidos pelo normalizador.
    final candidates = <int>[
      for (var i = 0; i < available.length; i++)
        if (normalizer.identify(available[i].name) != null) i,
    ];

    if (candidates.isEmpty) {
      setState(() {
        _error =
            'Nenhum ingrediente reconhecido foi encontrado '
            'na despensa.';
        _recipe = null;
      });
      return;
    }

    // Prazo exclusivo da geração de receitas por validade.
    const int warningDays = 7;

    // Produtos com validade mais próxima vêm primeiro.
    // Produtos sem data cadastrada ficam por último.
    candidates.sort((a, b) {
      final daysA = available[a].days ?? 999999;
      final daysB = available[b].days ?? 999999;

      return daysA.compareTo(daysB);
    });

    // Identifica os ingredientes efetivamente urgentes.
    final urgentCategories = <String>{};

    for (final index in candidates) {
      final product = available[index];
      final days = product.days;

      if (days != null && days >= 0 && days <= warningDays) {
        final ingredient = normalizer.identify(product.name);

        if (ingredient != null) {
          urgentCategories.add(ingredient.name);
        }
      }
    }

    if (urgentCategories.isEmpty) {
      setState(() {
        _error =
            'Nenhum ingrediente reconhecido está próximo '
            'do vencimento dentro do prazo de alerta '
            'de $warningDays dias.';
        _recipe = null;
      });
      return;
    }

    // Seleciona até 3 produtos, respeitando a prioridade.
    final chosenIndexes = candidates.take(3).toList();

    setState(() {
      _selected
        ..clear()
        ..addAll(chosenIndexes);

      _error = null;
      _recipe = null;
    });

    // Usa o mesmo fluxo de IA já existente,
    // mas exige uma referência que aproveite
    // pelo menos uma categoria urgente selecionada.
    await _generateRecipe(priorityCategoryNames: urgentCategories);
  }

  Future<void> _generateRecipe({
    Set<String> priorityCategoryNames = const {},
  }) async {
    if (_loading) return;

    final available = _availableProducts;

    final selectedProducts = [
      for (var i = 0; i < available.length; i++)
        if (_selected.contains(i)) available[i],
    ];

    if (selectedProducts.isEmpty) return;

    final normalizer = IngredientNormalizerService.instance;

    final recognizedProducts = selectedProducts
        .where((product) => normalizer.identify(product.name) != null)
        .toList();

    if (recognizedProducts.isEmpty) {
      setState(() {
        _error =
            'Ainda não conseguimos reconhecer os ingredientes '
            'selecionados. Tente outros produtos da despensa.';
        _recipe = null;
      });
      return;
    }

    if (recognizedProducts.length != selectedProducts.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alguns produtos ainda não são reconhecidos '
            'e não participarão desta receita.',
          ),
        ),
      );
    }

    setState(() {
      _loading = true;
      _error = null;
      _recipe = null;
    });

    try {
      // Etapa 1: encontra referências culinárias.
      final ranking = await TheMealDbRankingService.instance
          .searchAndRankProducts(products: recognizedProducts);

      if (!mounted) return;

      final usableReferences = ranking.where((item) {
        if (item.matchedCount == 0) {
          return false;
        }

        // Na geração manual, mantém o ranking normal.
        if (priorityCategoryNames.isEmpty) {
          return true;
        }

        // Na geração por validade, a receita precisa
        // aproveitar pelo menos um ingrediente urgente.
        return item.matchedIngredients.any(
          (name) => priorityCategoryNames.contains(name),
        );
      }).toList();

      if (usableReferences.isEmpty) {
        throw StateError(
          'Nenhuma referência culinária compatível foi encontrada.',
        );
      }

      // Etapa 2: escolhe a melhor referência do ranking.
      // Nesta primeira versão, usamos a primeira colocada.
      final reference = usableReferences.first.recipe;

      debugPrint('Chefim: referência selecionada: ${reference.name}');

      // Etapa 3: pede à Cloudflare a receita adaptada.
      final generated = await AiRecipeService.instance.adaptRecipe(
        products: recognizedProducts,
        reference: reference,
      );

      assert(() {
        debugPrint('\n========== RECEITA GERADA PELO CHEFIM ==========');

        final lines = _formatRecipe(generated).split('\n');

        for (final line in lines) {
          debugPrint(line);
        }

        debugPrint('===============================================\n');

        return true;
      }());

      if (!mounted) return;

      // Exibe a receita adaptada recebida do backend.
      setState(() {
        _recipe = generated;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Chefim: erro ao gerar receita: $error');

      if (!mounted) return;

      setState(() {
        _error = 'Erro no teste: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableProducts;

    return Scaffold(
      appBar: AppBar(title: const Text('Receitas do Chefim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Escolha até 3 produtos da sua despensa',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'O Chefim vai procurar uma referência culinária '
            'e adaptar a receita aos seus ingredientes.',
          ),
          const SizedBox(height: 16),

          if (available.isEmpty)
            const Text(
              'Nenhum produto com estoque disponível '
              'foi encontrado na despensa.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < available.length; i++)
                  FilterChip(
                    label: Text(available[i].name),
                    selected: _selected.contains(i),
                    onSelected: _loading
                        ? null
                        : (selected) {
                            if (selected && _selected.length >= 3) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selecione no máximo 3 produtos.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              if (selected) {
                                _selected.add(i);
                              } else {
                                _selected.remove(i);
                              }

                              _recipe = null;
                              _error = null;
                            });
                          },
                  ),
              ],
            ),

          const SizedBox(height: 22),

          FilledButton.icon(
            onPressed: _loading || _selected.isEmpty
                ? null
                : () => _generateRecipe(),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Gerar com ingredientes selecionados'),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _loading || available.isEmpty
                ? null
                : _generateExpiryRecipe,
            icon: const Icon(Icons.event_available),
            label: const Text('Gerar priorizando validade'),
          ),

          const SizedBox(height: 8),

          const Text(
            'No modo de validade, o Chefim escolhe '
            'automaticamente os produtos mais próximos '
            'do vencimento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),

          if (_loading) ...[
            const SizedBox(height: 28),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'O Chefim está preparando sua receita...',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'A pesquisa e a adaptação podem levar algum tempo.',
              textAlign: TextAlign.center,
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 20),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],

          if (_recipe != null) ...[
            const SizedBox(height: 28),
            _recipeView(_recipe!),
          ],
        ],
      ),
    );
  }

  String _formatRecipe(AiGeneratedRecipe recipe) {
    final buffer = StringBuffer();

    buffer.writeln('RECEITA: ${recipe.name}');
    buffer.writeln('Porções: ${recipe.servings}');
    buffer.writeln();

    buffer.writeln('INGREDIENTES SELECIONADOS:');

    for (final ingredient in recipe.ingredients) {
      if (ingredient.origin == 'selecionado') {
        buffer.writeln(
          '- ${ingredient.quantity} ${ingredient.unit} '
          'de ${ingredient.name}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('INGREDIENTES ADICIONAIS:');

    for (final ingredient in recipe.ingredients) {
      if (ingredient.origin == 'adicional') {
        buffer.writeln(
          '- ${ingredient.quantity} ${ingredient.unit} '
          'de ${ingredient.name}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('MODO DE PREPARO:');

    for (var i = 0; i < recipe.steps.length; i++) {
      buffer.writeln('${i + 1}. ${recipe.steps[i]}');
    }

    if (recipe.notes.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('OBSERVAÇÕES:');

      for (final note in recipe.notes) {
        buffer.writeln('- $note');
      }
    }

    return buffer.toString();
  }

  Future<void> _copyRecipe(AiGeneratedRecipe recipe) async {
    final text = _formatRecipe(recipe);

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receita copiada!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _recipeView(AiGeneratedRecipe recipe) {
    final pantryIngredients = recipe.ingredients
        .where((ingredient) => ingredient.origin == 'selecionado')
        .toList();

    final extraIngredients = recipe.ingredients
        .where((ingredient) => ingredient.origin == 'adicional')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),

        Text(
          recipe.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text('${recipe.servings} porções'),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () => _copyRecipe(recipe),
          icon: const Icon(Icons.copy),
          label: const Text('Copiar receita'),
        ),

        const SizedBox(height: 20),

        const Text(
          'Ingredientes selecionados',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (pantryIngredients.isEmpty)
          const Text('Nenhum ingrediente da despensa utilizado.'),

        for (final ingredient in pantryIngredients) _ingredientLine(ingredient),

        if (extraIngredients.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Ingredientes adicionais',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final ingredient in extraIngredients)
            _ingredientLine(ingredient),
        ],

        const SizedBox(height: 22),
        const Text(
          'Modo de preparo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        for (var i = 0; i < recipe.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${i + 1}. ${recipe.steps[i]}'),
          ),

        if (recipe.notes.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Observações',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final note in recipe.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $note'),
            ),
        ],
      ],
    );
  }

  Widget _ingredientLine(AiRecipeIngredient ingredient) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '• ${ingredient.quantity} ${ingredient.unit} '
        'de ${ingredient.name}',
      ),
    );
  }
}
