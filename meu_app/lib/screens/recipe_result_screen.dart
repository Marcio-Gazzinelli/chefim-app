part of '../main.dart';

class RecipeResultScreen extends StatefulWidget {
  const RecipeResultScreen({
    super.key,
    required this.recipe,
    required this.userId,
    required this.pantryProducts,
    this.notice,
    this.savedRecipeId,
  });

  final AiGeneratedRecipe recipe;
  final int? userId;
  final List<Product> pantryProducts;
  final String? notice;
  final int? savedRecipeId;

  @override
  State<RecipeResultScreen> createState() => _RecipeResultScreenState();
}

class _RecipeResultScreenState extends State<RecipeResultScreen> {
  bool _saving = false;
  late bool _saved;

  AiGeneratedRecipe get recipe => widget.recipe;

  @override
  void initState() {
    super.initState();
    _saved = widget.savedRecipeId != null;
  }

  String _ingredientText(AiRecipeIngredient ingredient) {
    final amount = [
      ingredient.quantity,
      ingredient.unit,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return amount.isEmpty ? ingredient.name : '${ingredient.name} · $amount';
  }

  String get _servingsLabel =>
      '${recipe.servings} ${recipe.servings == 1 ? 'porção' : 'porções'}';

  Future<void> _saveRecipe() async {
    if (_saving || _saved) return;

    setState(() => _saving = true);

    try {
      await DatabaseService.instance.insertSavedRecipe(
        userId: widget.userId,
        recipe: recipe,
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
        _saved = true;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Receita salva!')));
    } catch (error) {
      debugPrint('Chefim: erro ao salvar receita: $error');

      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a receita.')),
      );
    }
  }

  Future<void> _copy(
    BuildContext context,
    Map<String, List<String>> sections,
  ) async {
    final text = StringBuffer()
      ..writeln(recipe.name)
      ..writeln(_servingsLabel);

    if (recipe.estimatedCaloriesTotal case final calories?) {
      text.writeln('Calorias estimadas: ~$calories kcal no total');
    }

    if (recipe.estimatedCaloriesPerServing case final calories?) {
      text.writeln('~$calories kcal por porção');
    }

    for (final section in sections.entries) {
      if (section.value.isEmpty) continue;

      text
        ..writeln()
        ..writeln(section.key)
        ..writeln(section.value.join('\n'));
    }

    try {
      await Clipboard.setData(ClipboardData(text: text.toString().trimRight()));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Receita copiada!')));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível copiar a receita.')),
      );
    }
  }

  Widget _section({
    required BuildContext context,
    required String title,
    required List<String> entries,
    IconData? icon,
    Color? iconColor,
    String? helper,
  }) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: iconColor ?? darkGreen, size: 21),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: textTheme.titleMedium)),
              ],
            ),
            if (helper != null) ...[
              const SizedBox(height: 6),
              Text(helper, style: type(11, color: muted)),
            ],
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(entry),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final availability = RecipeIngredientAvailabilityService.instance;
    final availableIngredients = availability.availableIngredients(
      recipe: recipe,
      pantryProducts: widget.pantryProducts,
    );
    final missingIngredients = availability.missingIngredients(
      recipe: recipe,
      pantryProducts: widget.pantryProducts,
    );

    final sections = {
      'Ingredientes encontrados na despensa': [
        for (final ingredient in availableIngredients)
          '• ${_ingredientText(ingredient)}',
      ],
      'Ingredientes não encontrados na despensa': [
        for (final ingredient in missingIngredients)
          '• ${_ingredientText(ingredient)}',
      ],
      'Modo de preparo': [
        for (var index = 0; index < recipe.steps.length; index++)
          '${index + 1}. ${recipe.steps[index]}',
      ],
      'Observações': [for (final note in recipe.notes) '• $note'],
    };

    return Scaffold(
      appBar: AppBar(title: Text(_saved ? 'Receita salva' : 'Receita gerada')),
      body: SafeArea(
        child: scroll([
          Card(
            color: colors.primaryContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant_menu, color: colors.onPrimaryContainer),
                  const SizedBox(height: 12),
                  Text(
                    recipe.name,
                    style: text.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _servingsLabel,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (recipe.estimatedCaloriesPerServing != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_outlined,
                          color: colors.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '~${recipe.estimatedCaloriesPerServing} kcal por porção'
                            '${recipe.estimatedCaloriesTotal == null ? '' : ' · '
                                      '~${recipe.estimatedCaloriesTotal} kcal no total'}',
                            style: text.bodyMedium?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Estimativa baseada nos ingredientes e quantidades. '
                      'O valor real pode variar.',
                      style: text.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.notice case final message?) ...[
            const SizedBox(height: 12),
            Text(message, style: text.bodyMedium),
          ],
          if (missingIngredients.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: darkGreen),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Todos os ingredientes foram encontrados na sua despensa.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          _section(
            context: context,
            title: 'Ingredientes encontrados na despensa',
            entries: sections['Ingredientes encontrados na despensa']!,
            icon: Icons.inventory_2_outlined,
          ),
          _section(
            context: context,
            title: 'Ingredientes não encontrados na despensa',
            entries: sections['Ingredientes não encontrados na despensa']!,
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange.shade700,
            helper: 'Confira se você já possui esses itens antes de comprar.',
          ),
          _section(
            context: context,
            title: 'Modo de preparo',
            entries: sections['Modo de preparo']!,
            icon: Icons.format_list_numbered,
          ),
          _section(
            context: context,
            title: 'Observações',
            entries: sections['Observações']!,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saved || _saving ? null : _saveRecipe,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_saved ? Icons.bookmark : Icons.bookmark_add_outlined),
            label: Text(
              _saving
                  ? 'Salvando...'
                  : _saved
                  ? 'Receita salva'
                  : 'Salvar receita',
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _copy(context, sections),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar receita'),
          ),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.refresh),
            label: const Text('Gerar outra receita · Em breve'),
          ),
        ]),
      ),
    );
  }
}
