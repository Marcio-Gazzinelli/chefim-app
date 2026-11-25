part of '../main.dart';

class AiRecipeIngredient {
  const AiRecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.origin,
  });

  final String name;
  final String quantity;
  final String unit;
  final String origin;

  factory AiRecipeIngredient.fromJson(Map<String, dynamic> json) {
    return AiRecipeIngredient(
      name: json['nome'] as String,
      quantity: json['quantidade'] as String,
      unit: json['unidade'] as String,
      origin: json['origem'] as String,
    );
  }
}

class AiGeneratedRecipe {
  const AiGeneratedRecipe({
    required this.name,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.notes,
  });

  final String name;
  final int servings;
  final List<AiRecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> notes;

  factory AiGeneratedRecipe.fromJson(Map<String, dynamic> json) {
    return AiGeneratedRecipe(
      name: json['nome'] as String,
      servings: json['porcoes'] as int,
      ingredients: (json['ingredientes'] as List)
          .map(
            (item) => AiRecipeIngredient.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      steps: List<String>.from(json['preparo'] as List),
      notes: List<String>.from((json['observacoes'] as List?) ?? []),
    );
  }
}

class AiRecipeService {
  AiRecipeService._();

  static final instance = AiRecipeService._();

  // Configurável na execução do Flutter.
  static const String _baseUrl = String.fromEnvironment(
    'CHEFIM_API_URL',
    defaultValue: '',
  );

  Future<AiGeneratedRecipe> adaptRecipe({
    required List<Product> products,
    required Recipe reference,
  }) async {
    if (products.isEmpty || products.length > 3) {
      throw ArgumentError('Selecione de 1 a 3 produtos.');
    }

    final validProducts = products.every((product) {
      final days = product.days;

      return product.quantity.isFinite &&
          product.quantity > 0 &&
          (days == null || days >= 0);
    });

    if (!validProducts) {
      throw ArgumentError('A seleção contém produtos sem estoque ou vencidos.');
    }

    final payload = {
      'produtos': products.map((product) {
        final identified = IngredientNormalizerService.instance
            .identifyDetailed(product.name);

        return {
          'nome': product.name,
          'categoria': identified?.categoryKey,
          'variedade': identified?.varietyKey,
          'quantidade': product.quantity,
          'unidade': product.unit,
        };
      }).toList(),
      'referencia': {
        'nome': reference.name,
        'ingredientes': reference.ingredients
            .map((ingredient) => ingredient.name)
            .toList(),
        'preparo': reference.steps,
      },
    };

    // Para builds de distribuição, passe CHEFIM_API_URL via --dart-define.
    // Não existe dependência obrigatória de localhost, USB ou Wrangler.
    final apiUri = Uri.tryParse(_baseUrl);
    if (apiUri == null ||
        apiUri.scheme != 'https' ||
        apiUri.host.isEmpty ||
        apiUri.userInfo.isNotEmpty) {
      throw StateError('API do Chefim não configurada (HTTPS).');
    }

    final supabase = Supabase.instance.client;

    var session = supabase.auth.currentSession;

    // Cria uma identidade anônima somente quando necessário.
    if (session == null) {
      try {
        final response = await supabase.auth.signInAnonymously();
        session = response.session;
      } catch (error) {
        debugPrint('Chefim: erro na autenticação anônima: $error');

        throw StateError(
          'Não foi possível conectar ao serviço de receitas. '
          'Tente novamente.',
        );
      }
    }

    if (session == null) {
      throw StateError('Não foi possível iniciar a sessão de receitas.');
    }

    final uri = apiUri.resolve('/recipes/adapt');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 90));

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200) {
      final message = decoded is Map ? decoded['error'] : null;
      throw StateError(
        message is String && message.isNotEmpty
            ? message
            : 'Falha ao gerar receita. HTTP ${response.statusCode}',
      );
    }

    if (decoded is! Map || decoded['receita'] is! Map) {
      throw const FormatException('Resposta inesperada do backend.');
    }

    final generated = AiGeneratedRecipe.fromJson(
      Map<String, dynamic>.from(decoded['receita'] as Map),
    );

    if (generated.name.trim().isEmpty ||
        generated.servings <= 0 ||
        generated.ingredients.isEmpty ||
        generated.steps.length < 3) {
      throw const FormatException('A IA retornou uma receita incompleta.');
    }

    return generated;
  }
}
