import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const ChefimApp());

final nightMode = ValueNotifier<bool>(false);

Color get green =>
    nightMode.value ? const Color(0xFF52CE64) : const Color(0xFF32B43A);
Color get darkGreen =>
    nightMode.value ? const Color(0xFF7BE18A) : const Color(0xFF248A2A);
Color get softGreen =>
    nightMode.value ? const Color(0xFF203629) : const Color(0xFFE9F8EB);
Color get ink =>
    nightMode.value ? const Color(0xFFF2F7F2) : const Color(0xFF172019);
Color get muted =>
    nightMode.value ? const Color(0xFFB2C0B5) : const Color(0xFF9299AE);
Color get canvas =>
    nightMode.value ? const Color(0xFF101713) : const Color(0xFFFAFCF9);
Color get surface =>
    nightMode.value ? const Color(0xFF1B271E) : Colors.white;
Color get line =>
    nightMode.value ? const Color(0xFF314536) : const Color(0xFFEDF0ED);
Color get red =>
    nightMode.value ? const Color(0xFFFF8580) : const Color(0xFFEB5757);
Color get rose =>
    nightMode.value ? const Color(0xFF3C282B) : const Color(0xFFFFF0EF);
Color get gold =>
    nightMode.value ? const Color(0xFF3D3524) : const Color(0xFFFFF7DD);
Color get lavender =>
    nightMode.value ? const Color(0xFF322D45) : const Color(0xFFF1EFFF);
Color get milkTone =>
    nightMode.value ? const Color(0xFF283746) : const Color(0xFFEAF2FA);
Color get attentionStart =>
    nightMode.value ? const Color(0xFF223A29) : const Color(0xFFEFFBEF);
Color get attentionEnd =>
    nightMode.value ? const Color(0xFF1B2C21) : const Color(0xFFF9FFF8);

BoxShadow get shadow => BoxShadow(
      color: nightMode.value
          ? const Color(0x55000000)
          : const Color(0x12203E25),
      blurRadius: 28,
      offset: const Offset(0, 8),
    );

TextStyle type(double size, {bool bold = false, Color? color}) => TextStyle(
      fontSize: size,
      color: color ?? ink,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    );

class ChefimApp extends StatelessWidget {
  const ChefimApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: nightMode,
        builder: (context, isNight, _) => MaterialApp(
          title: 'Chefim',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: canvas,
            colorScheme: ColorScheme.fromSeed(
              seedColor: green,
              brightness: isNight ? Brightness.dark : Brightness.light,
            ),
            fontFamily: 'Roboto',
          ),
          home: const ChefimShell(),
        ),
      );
}

class Product {
  Product(this.name, this.expiryDate);

  final String name;
  final DateTime expiryDate;

  int get days => DateUtils.dateOnly(expiryDate)
      .difference(DateUtils.dateOnly(DateTime.now()))
      .inDays;

  String get date =>
      '${expiryDate.day.toString().padLeft(2, '0')}/'
      '${expiryDate.month.toString().padLeft(2, '0')}/'
      '${expiryDate.year}';
}

class ShoppingItem {
  ShoppingItem(this.name, {this.checked = false});

  final String name;
  bool checked;
}

class ChefimShell extends StatefulWidget {
  const ChefimShell({super.key});

  @override
  State<ChefimShell> createState() => _ChefimShellState();
}

class _ChefimShellState extends State<ChefimShell> {
  int tab = 0;
  String? name;
  String? email;

  // Conta temporária em memória, até a integração com autenticação e banco.
  String? registeredName;
  String? registeredEmail;
  String? registeredPassword;

  // Os produtos adicionados pelo usuário começam vazios.
  final products = <Product>[];

  final shopping = <ShoppingItem>[
    ShoppingItem('Banana'),
    ShoppingItem('Ovos', checked: true),
    ShoppingItem('Café'),
  ];

  void select(int next) => setState(() => tab = next);

  Future<void> open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [home(), pantry(), recipes(), profile()];

    return Scaffold(
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

  Widget nav(int index, String title, IconData icon) => Expanded(
        child: InkWell(
          onTap: () => select(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: index == tab ? green : muted,
                size: 25,
              ),
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

  Widget section(String title, String detail) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: type(15, bold: true)),
            ),
            Text(detail, style: type(11, color: muted)),
          ],
        ),
      );

  Widget home() {
    final expiring =
        products.where((product) => product.days <= 3).length;

    return scroll([
      Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Chefim',
                    style: type(23, bold: true, color: green),
                  ),
                  TextSpan(
                    text: '.',
                    style: type(23, bold: true),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => open(settingsPage(true)),
            icon: Icon(Icons.notifications_none, color: ink),
          ),
        ],
      ),
      const SizedBox(height: 17),
      Text(
        'BEM-VINDO AO CHEFIM',
        style: type(10, bold: true, color: darkGreen),
      ),
      const SizedBox(height: 5),
      Text(
        name == null
            ? 'Olá! 👋'
            : 'Olá, ${name!.trim().split(RegExp(r'\s+')).first}! 👋',
        style: type(28, bold: true),
      ),
      const SizedBox(height: 5),
      Text(
        'Que bom ter você por aqui!',
        style: type(14, color: muted),
      ),
      const SizedBox(height: 17),
      panel(
        Container(
          constraints: const BoxConstraints(minHeight: 176),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                attentionStart,
                attentionEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (expiring > 0) ...[
                      Text(
                        'ATENÇÃO',
                        style: type(10, bold: true, color: darkGreen),
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(
                      expiring > 0
                          ? 'Consuma antes, desperdice menos.'
                          : 'Tudo em dia!',
                      style: type(17, bold: true),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      expiring > 0
                          ? 'Você tem $expiring produto'
                              '${expiring == 1 ? '' : 's'} próximo'
                              '${expiring == 1 ? '' : 's'} do vencimento.'
                          : 'Nenhum produto perto do vencimento.',
                      style: type(12, color: muted),
                    ),
                    const SizedBox(height: 12),
                    smallButton('Ver produtos', () => select(1)),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: green,
                    size: 51,
                  ),
                  if (expiring > 0)
                    Positioned(
                      right: -5,
                      top: -8,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '!',
                          style: type(
                            16,
                            bold: true,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        custom: true,
      ),
      section('Resumo da sua despensa', 'Hoje'),
      Row(
        children: [
          Expanded(
            child: stat(
              '${products.length + 1}',
              'Produtos cadastrados',
              Icons.inventory_2_outlined,
              softGreen,
              darkGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: stat(
              '$expiring',
              'Próximos do vencimento',
              Icons.access_time,
              rose,
              red,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: stat(
              '0',
              'Receitas possíveis com seus itens',
              Icons.soup_kitchen_outlined,
              gold,
              const Color(0xFFD29219),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: stat(
              '650 kcal',
              'Total de calorias disponíveis',
              Icons.local_fire_department_outlined,
              lavender,
              const Color(0xFF7769CA),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      primary(
        'Escanear produto',
        () => open(const ScannerPage()),
        icon: Icons.qr_code_scanner_outlined,
        trailing: Icons.chevron_right,
      ),
    ]);
  }

  Widget stat(
    String value,
    String label,
    IconData icon,
    Color bg,
    Color fg,
  ) =>
      panel(
        SizedBox(
          height: 125,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge(icon, bg, fg),
              const SizedBox(height: 8),
              Text(value, style: type(22, bold: true)),
              Text(
                label,
                maxLines: 2,
                style: type(11, color: muted),
              ),
            ],
          ),
        ),
      );

  Widget pantry() {
    final expiring =
        products.where((product) => product.days <= 3).length;
    final milkExpiry =
        DateTime.now().add(const Duration(days: 5));

    return scroll([
      topbar('Minha despensa'),
      subtitle('Veja seus produtos e o que está perto de vencer.'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: softGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            badge(
              Icons.notifications_none,
              Colors.white,
              darkGreen,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expiring == 0
                      ? 'Nenhum produto vence'
                      : '$expiring produto'
                          '${expiring == 1 ? '' : 's'} vence'
                          '${expiring == 1 ? '' : 'm'}',
                  style: type(12, bold: true),
                ),
                Text(
                  'nos próximos 3 dias',
                  style: type(
                    12,
                    bold: expiring > 0,
                    color: expiring > 0 ? red : darkGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      primary(
        'Adicionar produto',
        addProduct,
        icon: Icons.add,
      ),
      section(
        'Produtos da despensa',
        '${products.length + 1} itens',
      ),
      ...products.map(
        (product) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: productCard(product),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: productCard(
          Product(
            'Leite',
            milkExpiry,
          ),
          example: true,
        ),
      ),
    ]);
  }

  Widget productCard(Product product, {bool example = false}) =>
      panel(
        Row(
          children: [
            badge(
              Icons.inventory_2_outlined,
              example ? milkTone : softGreen,
              ink,
              size: 52,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: type(13, bold: true),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.days < 0
                        ? 'Venceu há ${-product.days} dias'
                        : product.days == 0
                            ? 'Vence hoje'
                            : product.days == 1
                                ? 'Vence amanhã'
                                : 'Vence em ${product.days} dias',
                    style: type(
                      11,
                      color: product.days <= 3 ? red : darkGreen,
                    ),
                  ),
                  Text(
                    example
                        ? '${product.date} • Exemplo: 1 L integral'
                        : product.date,
                    style: type(10, color: muted),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 4,
              backgroundColor:
                  product.days <= 3 ? red : green,
            ),
          ],
        ),
      );

  Future<void> addProduct() async {
    final item = TextEditingController();
    DateTime? expiryDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(27),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            22,
            22,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar produto',
                  style: type(20, bold: true),
                ),
                const SizedBox(height: 5),
                Text(
                  'Inclua um item e acompanhe sua validade.',
                  style: type(12, color: muted),
                ),
                const SizedBox(height: 20),
                field(
                  'Nome do produto',
                  'Ex.: Café',
                  item,
                ),
                const SizedBox(height: 14),
                Text(
                  'Data de vencimento',
                  style: type(12, bold: true),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final today = DateUtils.dateOnly(DateTime.now());
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: expiryDate ?? today,
                        firstDate: today,
                        lastDate: DateTime(today.year + 20, 12, 31),
                      );
                      if (picked != null && sheetContext.mounted) {
                        refreshSheet(() => expiryDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      expiryDate == null
                          ? 'Selecionar data'
                          : '${expiryDate!.day.toString().padLeft(2, '0')}/'
                            '${expiryDate!.month.toString().padLeft(2, '0')}/'
                            '${expiryDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                primary('Adicionar à despensa', () {
                  if (item.text.trim().isEmpty || expiryDate == null) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Informe o produto e a data de vencimento.',
                        ),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    products.insert(
                      0,
                      Product(
                        item.text.trim(),
                        expiryDate!,
                      ),
                    );
                  });

                  Navigator.pop(sheetContext);
                }),
              ],
            ),
          ),
        ),
      ),
    );

    item.dispose();
  }

  Widget recipes() {
    return scroll([
      topbar(
        'Receitas',
        action: IconButton(
          tooltip: 'Pesquisar receitas',
          onPressed: () => open(const ScaledRecipesPage()),
          icon: Icon(
            Icons.search,
            color: darkGreen,
          ),
        ),
      ),
      subtitle('Com o que você tem na despensa'),
      Row(
        children: [
          Expanded(
            child: Text(
              'Ideias para hoje',
              style: type(14, bold: true),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '0 disponíveis',
              style: type(
                10,
                bold: true,
                color: darkGreen,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      Center(
        child: Column(
          children: [
            badge(
              Icons.soup_kitchen_outlined,
              softGreen,
              darkGreen,
              size: 62,
            ),
            const SizedBox(height: 14),
            Text(
              'Nenhuma receita disponível',
              style: type(15, bold: true),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget profile() => scroll([
        topbar('Perfil'),
        const SizedBox(height: 12),
        panel(
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: green,
                child: name == null
                    ? const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                      )
                    : Text(
                        name![0].toUpperCase(),
                        style: type(
                          21,
                          bold: true,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Visitante',
                      style: type(15, bold: true),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email ??
                          'Crie sua conta para salvar seus dados',
                      style: type(11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: 9,
          ),
          child: Text(
            'SUA CONTA',
            style: type(
              10,
              bold: true,
              color: darkGreen,
            ),
          ),
        ),
        panel(
          Column(
            children: [
              menu(
                name == null ? 'Criar conta' : 'Minha conta',
                Icons.person_outline,
                () => open(
                  name == null ? registerPage() : accountPage(),
                ),
              ),
              menu(
                'Lista de compras',
                Icons.shopping_cart_outlined,
                () => open(shoppingPage()),
              ),
              menu(
                'Notificações',
                Icons.notifications_none,
                () => open(settingsPage(true)),
              ),
              menu(
                'Configurações',
                Icons.settings_outlined,
                () => open(settingsPage(false)),
              ),
              menu(
                'Sobre o Chefim',
                Icons.info_outline,
                () => open(aboutPage()),
                last: true,
              ),
            ],
          ),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        if (name != null)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  name = null;
                  email = null;
                  tab = 0;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: red,
                side: BorderSide(color: red),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
          ),
      ]);

  Widget menu(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool last = false,
  }) =>
      Column(
        children: [
          ListTile(
            onTap: onTap,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            leading: badge(
              icon,
              softGreen,
              darkGreen,
            ),
            title: Text(
              label,
              style: type(12),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: muted,
            ),
          ),
          if (!last) Divider(height: 1, color: line),
        ],
      );

  Widget accountPage() => EntryPage(
        title: 'Minha conta',
        builder: (pageContext, refresh) => [
          const SizedBox(height: 18),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nome', style: type(12, color: muted)),
                Text(name ?? '', style: type(15, bold: true)),
                const SizedBox(height: 16),
                Text('E-mail', style: type(12, color: muted)),
                Text(email ?? '', style: type(15, bold: true)),
              ],
            ),
          ),
        ],
      );

  Widget registerPage() {
    final person = TextEditingController();
    final mail = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    return EntryPage(
      title: 'Criar conta',
      builder: (pageContext, refresh) => [
        const SizedBox(height: 12),
        Center(
          child: badge(
            Icons.person_outline,
            softGreen,
            darkGreen,
            size: 52,
          ),
        ),
        const SizedBox(height: 11),
        Center(
          child: Text(
            'Comece a usar o Chefim',
            style: type(23, bold: true),
          ),
        ),
        const SizedBox(height: 7),
        Center(
          child: Text(
            'Cadastre-se para salvar sua despensa\n'
            'e receber alertas de validade.',
            style: type(12, color: muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 22),
        field(
          'Nome completo',
          'Digite seu nome',
          person,
        ),
        const SizedBox(height: 14),
        field(
          'E-mail',
          'seuemail@exemplo.com',
          mail,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        field(
          'Senha',
          'Mínimo de 6 caracteres',
          pass,
          hidden: true,
        ),
        const SizedBox(height: 14),
        field(
          'Confirmar senha',
          'Repita sua senha',
          confirm,
          hidden: true,
        ),
        const SizedBox(height: 16),
        primary('Criar conta', () {
          if (person.text.trim().isEmpty ||
              !mail.text.contains('@') ||
              pass.text.length < 6 ||
              pass.text != confirm.text) {
            ScaffoldMessenger.of(pageContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'Confira nome, e-mail e senha '
                  '(mínimo de 6 caracteres).',
                ),
              ),
            );
            return;
          }

          setState(() {
            name = person.text.trim();
            email = mail.text.trim();
            registeredName = name;
            registeredEmail = email;
            registeredPassword = pass.text;
            tab = 0;
          });

          Navigator.pop(pageContext);
        }),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushReplacement(
              pageContext,
              MaterialPageRoute(builder: (_) => loginPage()),
            ),
            child: const Text('Já possui uma conta? Entrar'),
          ),
        ),
      ],
    );
  }

  Widget loginPage() {
    final mail = TextEditingController();
    final pass = TextEditingController();

    return EntryPage(
      title: 'Entrar',
      builder: (pageContext, refresh) => [
        const SizedBox(height: 12),
        Center(
          child: badge(
            Icons.lock_outline,
            softGreen,
            darkGreen,
            size: 52,
          ),
        ),
        const SizedBox(height: 11),
        Center(
          child: Text(
            'Entre na sua conta',
            style: type(23, bold: true),
          ),
        ),
        const SizedBox(height: 22),
        field(
          'E-mail',
          'seuemail@exemplo.com',
          mail,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        field('Senha', 'Digite sua senha', pass, hidden: true),
        const SizedBox(height: 18),
        primary('Entrar', () {
          if (registeredEmail == null ||
              registeredPassword == null) {
            ScaffoldMessenger.of(pageContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'Crie uma conta para entrar nesta versão do app.',
                ),
              ),
            );
            return;
          }

          if (mail.text.trim().toLowerCase() !=
                  registeredEmail!.toLowerCase() ||
              pass.text != registeredPassword) {
            ScaffoldMessenger.of(pageContext).showSnackBar(
              const SnackBar(
                content: Text('E-mail ou senha incorretos.'),
              ),
            );
            return;
          }

          setState(() {
            name = registeredName;
            email = registeredEmail;
            tab = 0;
          });
          Navigator.pop(pageContext);
        }),
      ],
    );
  }

  Widget shoppingPage() {
    final draft = TextEditingController();

    return EntryPage(
      title: 'Lista de compras',
      builder: (pageContext, refresh) => [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: draft,
                decoration: input('Digite um produto'),
                onSubmitted: (_) => addShopping(draft, refresh),
              ),
            ),
            const SizedBox(width: 9),
            IconButton.filled(
              onPressed: () => addShopping(draft, refresh),
              style: IconButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${shopping.where((item) => item.checked).length} '
                'de ${shopping.length} comprados',
                style: type(10, color: muted),
              ),
            ),
            TextButton(
              onPressed: () => refresh(() => shopping.clear()),
              child: const Text('Limpar lista'),
            ),
          ],
        ),
        if (shopping.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Column(
                children: [
                  badge(
                    Icons.shopping_cart_outlined,
                    softGreen,
                    darkGreen,
                    size: 66,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Sua lista está vazia.',
                    style: type(15, bold: true),
                  ),
                  Text(
                    'Adicione o primeiro produto!',
                    style: type(12, color: muted),
                  ),
                ],
              ),
            ),
          )
        else
          panel(
            Column(
              children: [
                for (final item in shopping)
                  Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: item.checked,
                            activeColor: green,
                            onChanged: (value) {
                              refresh(() {
                                item.checked = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                color: item.checked ? muted : ink,
                                fontSize: 13,
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              refresh(
                                () => shopping.remove(item),
                              );
                            },
                            icon: Icon(
                              Icons.delete_outline,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      if (item != shopping.last)
                        Divider(height: 1, color: line),
                    ],
                  ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 9),
          ),
      ],
    );
  }

  void addShopping(
    TextEditingController draft,
    void Function(VoidCallback) refresh,
  ) {
    if (draft.text.trim().isEmpty) return;

    refresh(() {
      shopping.add(ShoppingItem(draft.text.trim()));
      draft.clear();
    });
  }

  Widget aboutPage() => EntryPage(
        title: 'Sobre o Chefim',
        builder: (pageContext, refresh) => [
          const SizedBox(height: 8),
          panel(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    'CHEFIM.',
                    style: type(30, bold: true, color: green),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sua despensa inteligente',
                    style: type(14, bold: true),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'O Chefim ajuda você a organizar alimentos, '
                    'acompanhar validades e aproveitar melhor '
                    'suas compras.',
                    textAlign: TextAlign.center,
                    style: type(11, color: muted),
                  ),
                ],
              ),
            ),
            custom: true,
          ),
          section('Como funciona?', ''),
          step(
            '1',
            'Cadastre seus produtos',
            'Registre alimentos e datas de validade.',
          ),
          step(
            '2',
            'Receba alertas',
            'Saiba o que está perto de vencer.',
          ),
          step(
            '3',
            'Encontre receitas',
            'Use ingredientes antes que estraguem.',
          ),
          const SizedBox(height: 8),
          panel(
            Row(
              children: [
                badge(
                  Icons.soup_kitchen_outlined,
                  softGreen,
                  darkGreen,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projeto acadêmico',
                      style: type(13, bold: true),
                    ),
                    Text(
                      'Sprint 2 — Engenharia de Computação',
                      style: type(11, color: muted),
                    ),
                    Text(
                      'Versão 1.0 • 2026',
                      style: type(10, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: pageContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Termos e Privacidade'),
                    content: const Text(
                      'Este protótipo acadêmico não coleta nem '
                      'armazena dados pessoais. Uma política '
                      'completa será disponibilizada antes '
                      'do lançamento.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext),
                        child: const Text('Entendi'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text(
                'Termos e Política de Privacidade',
              ),
            ),
          ),
        ],
      );

  Widget step(
    String number,
    String title,
    String text,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            badge(Icons.circle, softGreen, darkGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number  $title',
                    style: type(13, bold: true),
                  ),
                  Text(
                    text,
                    style: type(11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget settingsPage(bool notifications) {
    final flags = [true, true, false];

    return EntryPage(
      title: notifications ? 'Notificações' : 'Configurações',
      builder: (pageContext, refresh) {
        final labels = notifications
            ? [
                'Produtos perto do vencimento',
                'Novas receitas disponíveis',
                'Lembretes da lista de compras',
              ]
            : [
                'Modo econômico de dados',
                'Sincronização automática',
                'Sugestões personalizadas',
              ];

        return [
          subtitle(
            notifications
                ? 'Escolha os alertas que quer receber.'
                : 'Personalize sua experiência no Chefim.',
          ),
          panel(
            Column(
              children: [
                if (!notifications)
                  SwitchListTile(
                    title: Text('Modo noturno', style: type(12)),
                    value: nightMode.value,
                    activeTrackColor: green,
                    onChanged: (value) {
                      nightMode.value = value;
                      refresh(() {});
                    },
                  ),
                for (int i = 0; i < 3; i++)
                  SwitchListTile(
                    title: Text(labels[i], style: type(12)),
                    value: flags[i],
                    activeTrackColor: green,
                    onChanged: (value) {
                      refresh(() => flags[i] = value);
                    },
                  ),
              ],
            ),
            padding: EdgeInsets.zero,
          ),
        ];
      },
    );
  }
}

Widget scroll(List<Widget> children) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: children,
    );

Widget topbar(
  String title, {
  VoidCallback? back,
  Widget? action,
}) =>
    SizedBox(
      height: 50,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: back == null
                ? null
                : IconButton(
                    onPressed: back,
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 19,
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: type(18, bold: true),
            ),
          ),
          SizedBox(
            width: 44,
            child: action,
          ),
        ],
      ),
    );

Widget subtitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: type(13, color: muted),
      ),
    );

Widget panel(
  Widget child, {
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  bool custom = false,
}) =>
    Container(
      padding: custom ? EdgeInsets.zero : padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [shadow],
      ),
      child: child,
    );

Widget badge(
  IconData icon,
  Color background,
  Color foreground, {
  double size = 35,
}) =>
    Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .31),
      ),
      child: Icon(
        icon,
        size: size * .56,
        color: foreground,
      ),
    );

Widget primary(
  String text,
  VoidCallback onTap, {
  IconData? icon,
  IconData? trailing,
}) =>
    SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 21),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: type(
                13,
                bold: true,
                color: Colors.white,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Icon(trailing),
            ],
          ],
        ),
      ),
    );

Widget smallButton(
  String text,
  VoidCallback onTap,
) =>
    SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          text,
          style: type(
            12,
            bold: true,
            color: Colors.white,
          ),
        ),
      ),
    );

InputDecoration input(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: type(13, color: muted),
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: green, width: 1.5),
      ),
    );

Widget field(
  String title,
  String hint,
  TextEditingController controller, {
  bool hidden = false,
  TextInputType? keyboard,
}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: type(12, bold: true)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: hidden,
          keyboardType: keyboard,
          decoration: input(hint),
        ),
      ],
    );

class EntryPage extends StatefulWidget {
  const EntryPage({
    super.key,
    required this.title,
    required this.builder,
  });

  final String title;
  final List<Widget> Function(
    BuildContext,
    void Function(VoidCallback),
  ) builder;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: scroll([
            topbar(
              widget.title,
              back: () => Navigator.pop(context),
            ),
            ...widget.builder(
              context,
              (fn) => setState(fn),
            ),
          ]),
        ),
      );
}

class ScaledRecipesPage extends StatefulWidget {
  const ScaledRecipesPage({super.key});

  @override
  State<ScaledRecipesPage> createState() =>
      _ScaledRecipesPageState();
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
            topbar(
              'Receitas',
              back: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: input('Pesquisar uma receita').copyWith(
                prefixIcon: Icon(
                  Icons.search,
                  color: darkGreen,
                ),
              ),
            ),
          ]),
        ),
      );
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final camera = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );

  bool found = false;

  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  Future<void> detected(BarcodeCapture data) async {
    if (found || data.barcodes.isEmpty) return;

    final code = data.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    found = true;
    await camera.stop();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Produto escaneado'),
        content: Text(
          'Código identificado com sucesso\n\n$code',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );

    if (mounted) {
      found = false;
      await camera.start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B100C),
        body: SafeArea(
          child: Stack(
            children: [
              MobileScanner(
                controller: camera,
                onDetect: detected,
              ),
              Positioned(
                top: 2,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Escanear produto',
                        textAlign: TextAlign.center,
                        style: type(
                          18,
                          bold: true,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => camera.toggleTorch(),
                      icon: const Icon(
                        Icons.flash_on_outlined,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => camera.switchCamera(),
                      icon: const Icon(
                        Icons.cameraswitch_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  width: 266,
                  height: 188,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: green,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
              Positioned(
                bottom: 55,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: green,
                      size: 35,
                    ),
                    const SizedBox(height: 11),
                    Text(
                      'Aponte a câmera para o\n'
                      'código de barras do produto',
                      textAlign: TextAlign.center,
                      style: type(
                        13,
                        bold: true,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}