part of '../main.dart';

enum PantryFilter { all, expiring, expired }

class ChefimShell extends StatefulWidget {
  const ChefimShell({super.key});

  @override
  State<ChefimShell> createState() => _ChefimShellState();
}

class _ChefimShellState extends State<ChefimShell> {
  int tab = 0;
  int? currentUserId;
  String? name;
  String? email;

  final products = <Product>[];

  PantryFilter pantryFilter = PantryFilter.all;
  int expiryWarningDays = 3;

  bool sessionLoading = true;
  bool productsLoading = true;
  String? productsError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<int> _readExpiryWarningDays() async {
    try {
      final savedDays = await PreferencesService.instance
          .getExpiryWarningDays();

      return savedDays > 0 ? savedDays : 3;
    } catch (_) {
      return 3;
    }
  }

  Future<void> _initializeApp() async {
    try {
      final savedUserId = await PreferencesService.instance.getCurrentUserId();

      final savedUser = savedUserId == null
          ? null
          : await DatabaseService.instance.getUserById(savedUserId);

      if (savedUserId != null && savedUser == null) {
        await PreferencesService.instance.clearCurrentUserId();
      }

      final savedProducts = await DatabaseService.instance.getProducts(
        userId: savedUser?.id,
      );

      final savedExpiryWarningDays = await _readExpiryWarningDays();

      if (!mounted) return;

      setState(() {
        currentUserId = savedUser?.id;
        name = savedUser?.name;
        email = savedUser?.email;
        expiryWarningDays = savedExpiryWarningDays;

        products
          ..clear()
          ..addAll(savedProducts);

        sessionLoading = false;
        productsLoading = false;
        productsError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        sessionLoading = false;
        productsLoading = false;
        productsError = 'Não foi possível carregar os dados do aplicativo.';
      });
    }
  }

  Future<void> _reloadExpiryWarningDays() async {
    final savedExpiryWarningDays = await _readExpiryWarningDays();

    if (!mounted) return;

    setState(() {
      expiryWarningDays = savedExpiryWarningDays;
    });
  }

  Future<void> loadProducts() async {
    if (mounted) {
      setState(() {
        productsLoading = true;
        productsError = null;
      });
    }

    try {
      final savedProducts = await DatabaseService.instance.getProducts(
        userId: currentUserId,
      );

      if (!mounted) return;

      setState(() {
        products
          ..clear()
          ..addAll(savedProducts);

        productsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        productsLoading = false;
        productsError = 'Não foi possível carregar a despensa.';
      });
    }
  }

  Future<void> startUserSession(AppUser user) async {
    final userId = user.id;

    if (userId == null) {
      throw StateError('A conta precisa ter um identificador.');
    }

    await PreferencesService.instance.setCurrentUserId(userId);

    if (!mounted) return;

    setState(() {
      currentUserId = userId;
      name = user.name;
      email = user.email;
      pantryFilter = PantryFilter.all;
      tab = 0;
    });

    await loadProducts();
  }

  Future<void> endUserSession() async {
    await PreferencesService.instance.clearCurrentUserId();

    if (!mounted) return;

    setState(() {
      currentUserId = null;
      name = null;
      email = null;
      pantryFilter = PantryFilter.all;
      tab = 0;
    });

    await loadProducts();
  }

  Future<void> deleteCurrentAccount() async {
    final userId = currentUserId;

    if (userId == null) {
      throw StateError('Nenhuma conta está conectada.');
    }

    await DatabaseService.instance.deleteUser(userId);

    try {
      await PreferencesService.instance.clearCurrentUserId();
    } catch (error) {
      debugPrint(
        'Não foi possível limpar imediatamente '
        'a sessão excluída: $error',
      );
    }

    if (!mounted) return;

    setState(() {
      currentUserId = null;
      name = null;
      email = null;
      pantryFilter = PantryFilter.all;
      tab = 0;
    });

    await loadProducts();
  }

  void select(int next) {
    setState(() {
      tab = next;

      if (next == 1) {
        pantryFilter = PantryFilter.all;
      }
    });
  }

  void openPantry([PantryFilter filter = PantryFilter.all]) {
    setState(() {
      pantryFilter = filter;
      tab = 1;
    });
  }

  void setPantryFilter(PantryFilter filter) {
    setState(() {
      pantryFilter = filter;
    });
  }

  Future<void> scanProduct() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ScannerPage(userId: currentUserId)),
    );

    if (changed == true) {
      await loadProducts();
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    if (!mounted) return;

    await _reloadExpiryWarningDays();
  }

  @override
  Widget build(BuildContext context) {
    if (sessionLoading) {
      return Scaffold(
        backgroundColor: canvas,
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    }

    final pages = [home(), pantry(), recipes(), profile()];

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: surface,
            border: Border(top: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              nav(0, 'Início', Icons.home_outlined),
              nav(1, 'Despensa', Icons.inventory_2_outlined),
              nav(2, 'Receitas', Icons.soup_kitchen_outlined),
              nav(3, 'Perfil', Icons.person_outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget nav(int index, String title, IconData icon) {
    return Expanded(
      child: InkWell(
        onTap: () => select(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: index == tab ? green : muted, size: 25),
            const SizedBox(height: 4),
            Text(
              title,
              style: type(
                10,
                bold: index == tab,
                color: index == tab ? green : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget section(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: type(15, bold: true))),
          Text(detail, style: type(11, color: muted)),
        ],
      ),
    );
  }

  void refresh(VoidCallback action) {
    setState(action);
  }
}
