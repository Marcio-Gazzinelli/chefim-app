part of '../main.dart';

class RecipeResultScreen extends StatelessWidget {
  const RecipeResultScreen({
    super.key,
    required this.recipe,
    this.notice,
  });

  final AiGeneratedRecipe recipe;
  final String? notice;

  String _ingredientText(AiRecipeIngredient ingredient) {
    final amount = [ingredient.quantity, ingredient.unit]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');

    return amount.isEmpty
        ? ingredient.name
        : '${ingredient.name} · $amount';
  }

  String get _servingsLabel =>
      '${recipe.servings} ${recipe.servings == 1 ? 'porção' : 'porções'}';

  Future<void> _copy(
    BuildContext context,
    Map<String, List<String>> sections,
  ) async {
    final text = StringBuffer()
      ..writeln(recipe.name)
      ..writeln(_servingsLabel);

    for (final section in sections.entries) {
      if (section.value.isEmpty) continue;

      text
        ..writeln()
        ..writeln(section.key)
        ..writeln(section.value.join('\n'));
    }

    try {
      await Clipboard.setData(
        ClipboardData(text: text.toString().trimRight()),
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receita copiada!')),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível copiar a receita.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final sections = {
      'Ingredientes da despensa': [
        for (final ingredient in recipe.ingredients)
          if (ingredient.origin == 'selecionado')
            '• ${_ingredientText(ingredient)}',
      ],
      'Ingredientes adicionais': [
        for (final ingredient in recipe.ingredients)
          if (ingredient.origin != 'selecionado')
            '• ${_ingredientText(ingredient)}',
      ],
      'Modo de preparo': [
        for (var index = 0; index < recipe.steps.length; index++)
          '${index + 1}. ${recipe.steps[index]}',
      ],
      'Observações': [
        for (final note in recipe.notes) '• $note',
      ],
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receita gerada'),
      ),
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
                  Icon(
                    Icons.restaurant_menu,
                    color: colors.onPrimaryContainer,
                  ),
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
                ],
              ),
            ),
          ),
          if (notice case final message?) ...[
            const SizedBox(height: 12),
            Text(message, style: text.bodyMedium),
          ],
          for (final section in sections.entries)
            if (section.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        section.key,
                        style: text.titleMedium,
                      ),
                      for (final entry in section.value)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(entry),
                        ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 20),
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