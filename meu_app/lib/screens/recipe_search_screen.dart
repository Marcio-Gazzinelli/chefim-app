part of '../main.dart';

class ScaledRecipesPage extends StatefulWidget {
  const ScaledRecipesPage({super.key});

  @override
  State<ScaledRecipesPage> createState() => _ScaledRecipesPageState();
}

class _ScaledRecipesPageState extends State<ScaledRecipesPage> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: scroll([
        topbar('Receitas', back: () => Navigator.pop(context)),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: input('Pesquisar uma receita')
              .copyWith(prefixIcon: Icon(Icons.search, color: darkGreen)),
        ),
      ]),
    ),
  );
}
