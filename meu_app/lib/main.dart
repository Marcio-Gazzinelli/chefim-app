import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const ChefimApp());
}

const Color verdeChefim = Color(0xFF32B43A);
const Color cinzaChefim = Color(0xFF9299AE);

// Dados temporários do usuário. Quando o Firebase for conectado, esses valores
// devem vir do usuário autenticado.
final ValueNotifier<String?> nomeUsuarioChefim = ValueNotifier<String?>(null);
final ValueNotifier<String?> emailUsuarioChefim = ValueNotifier<String?>(null);

String primeiroNome(String nomeCompleto) {
  final nome = nomeCompleto.trim();
  if (nome.isEmpty) return '';
  return nome.split(RegExp(r'\s+')).first;
}

Future<void> abrirScannerProduto(BuildContext context) async {
  final codigo = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const ScannerProdutoPage()),
  );

  if (codigo == null || !context.mounted) return;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Produto escaneado'),
      content: Text(
        'Código encontrado:\n\n$codigo\n\n'
        'Na próxima etapa podemos consultar uma base de produtos e '
        'preencher automaticamente o nome, marca e categoria.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Fechar',
            style: TextStyle(color: verdeChefim),
          ),
        ),
      ],
    ),
  );
}

class ChefimApp extends StatelessWidget {
  const ChefimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chefim',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: verdeChefim),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  final int initialIndex;

  const MainPage({super.key, this.initialIndex = 0});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      InicioPage(
        onAbrirDespensa: () {
          setState(() {
            index = 1;
          });
        },
      ),
      const DespensaPage(),
      const ReceitasPage(),
      const PerfilPage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: verdeChefim,
        unselectedItemColor: const Color(0xFF9AA2B2),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (novoIndex) {
          setState(() {
            index = novoIndex;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Despensa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            activeIcon: Icon(Icons.access_time_filled),
            label: 'Receitas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class InicioPage extends StatelessWidget {
  final VoidCallback onAbrirDespensa;

  const InicioPage({super.key, required this.onAbrirDespensa});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chefim',
                  style: TextStyle(
                    color: verdeChefim,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: 'Notificações',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Você não possui novas notificações.'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: verdeChefim,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ValueListenableBuilder<String?>(
              valueListenable: nomeUsuarioChefim,
              builder: (context, nome, _) {
                final nomeExibido = nome == null ? '' : primeiroNome(nome);
                return Text(
                  nomeExibido.isEmpty ? 'Olá! 👋' : 'Olá, $nomeExibido! 👋',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'Que bom ter você por aqui!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Atenção',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Você tem 3 produtos próximos\ndo vencimento.',
                          style: TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 13),
                        ElevatedButton(
                          onPressed: onAbrirDespensa,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verdeChefim,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Ver produtos'),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: verdeChefim,
                          size: 48,
                        ),
                      ),
                      Positioned(
                        right: -7,
                        bottom: -7,
                        child: Container(
                          width: 37,
                          height: 37,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Resumo da sua despensa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 13),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.34,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                ResumoDespensaCard(
                  valor: '12',
                  descricao: 'Produtos\ncadastrados',
                  icone: Icons.inventory_2_outlined,
                  corIcone: verdeChefim,
                  fundoIcone: Color(0xFFEAF8E8),
                ),
                ResumoDespensaCard(
                  valor: '3',
                  descricao: 'Próximos do\nvencimento',
                  icone: Icons.alarm_rounded,
                  corIcone: Colors.red,
                  fundoIcone: Color(0xFFFFECE8),
                  corValor: Colors.red,
                ),
                ResumoDespensaCard(
                  valor: '5',
                  descricao: 'Receitas possíveis\ncom seus itens',
                  icone: Icons.soup_kitchen_outlined,
                  corIcone: Color(0xFF2474A8),
                  fundoIcone: Color(0xFFEAF5FC),
                ),
                ResumoDespensaCard(
                  valor: '1.250',
                  descricao: 'Total de calorias\ndisponíveis',
                  icone: Icons.local_fire_department_outlined,
                  corIcone: Color(0xFFF29B18),
                  fundoIcone: Color(0xFFFFF5D8),
                  corValor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 27),
            Material(
              color: verdeChefim,
              borderRadius: BorderRadius.circular(32),
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () => abrirScannerProduto(context),
                child: Container(
                  width: double.infinity,
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Spacer(),
                      const Text(
                        'Escanear produto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 47,
                        height: 47,
                        decoration: const BoxDecoration(
                          color: Color(0xFF159A24),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class ResumoDespensaCard extends StatelessWidget {
  final String valor;
  final String descricao;
  final IconData icone;
  final Color corIcone;
  final Color fundoIcone;
  final Color corValor;

  const ResumoDespensaCard({
    super.key,
    required this.valor,
    required this.descricao,
    required this.icone,
    required this.corIcone,
    required this.fundoIcone,
    this.corValor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                valor,
                style: TextStyle(
                  color: corValor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                descricao,
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: fundoIcone,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: corIcone, size: 21),
            ),
          ),
        ],
      ),
    );
  }
}

class CriarContaPage extends StatefulWidget {
  const CriarContaPage({super.key});

  @override
  State<CriarContaPage> createState() => _CriarContaPageState();
}

class _CriarContaPageState extends State<CriarContaPage> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  void criarConta() {
    if (nomeController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        senhaController.text.isEmpty ||
        confirmarController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos.')),
      );
      return;
    }

    if (senhaController.text != confirmarController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não são iguais.')),
      );
      return;
    }

    nomeUsuarioChefim.value = nomeController.text.trim();
    emailUsuarioChefim.value = emailController.text.trim();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: verdeChefim,
                        size: 20,
                      ),
                    ),
                  ),
                  const Text(
                    'Criar conta',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Comece a usar o Chefim',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cadastre-se para salvar sua despensa\n'
                'e receber alertas de validade.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cinzaChefim,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              CampoChefim(
                titulo: 'Nome completo',
                dica: 'Digite seu nome',
                controller: nomeController,
              ),
              const SizedBox(height: 18),
              CampoChefim(
                titulo: 'E-mail',
                dica: 'Digite seu e-mail',
                controller: emailController,
                tipo: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              CampoChefim(
                titulo: 'Senha',
                dica: 'Digite sua senha',
                controller: senhaController,
                senha: true,
              ),
              const SizedBox(height: 18),
              CampoChefim(
                titulo: 'Confirmar senha',
                dica: 'Repita sua senha',
                controller: confirmarController,
                senha: true,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: criarConta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeChefim,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Criar conta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Já possui uma conta? Entrar',
                  style: TextStyle(color: verdeChefim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CampoChefim extends StatelessWidget {
  final String titulo;
  final String dica;
  final TextEditingController controller;
  final bool senha;
  final TextInputType? tipo;

  const CampoChefim({
    super.key,
    required this.titulo,
    required this.dica,
    required this.controller,
    this.senha = false,
    this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: senha,
          keyboardType: tipo,
          decoration: InputDecoration(
            hintText: dica,
            hintStyle: const TextStyle(color: Color(0xFFC3C9D3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: verdeChefim,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DespensaPage extends StatelessWidget {
  const DespensaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: Text(
              'Minha despensa',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Veja seus produtos e o que está perto de vencer.',
            style: TextStyle(color: cinzaChefim, fontSize: 15),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: verdeChefim),
                SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '1 produto vence\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'nos próximos 3 dias',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Adicionar produto manualmente será ligado ao banco de dados.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Adicionar produto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: verdeChefim,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Produtos da despensa',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const ProdutoCard(
            nome: 'Queijo Mussarela',
            validade: 'Vence em 2 dias',
            data: '26/08/2026',
            cor: Color(0xFFFFCA3A),
            urgente: true,
          ),
          const ProdutoCard(
            nome: 'Leite',
            validade: 'Vence em 5 dias',
            data: '29/08/2026',
            cor: Color(0xFFE1E4EA),
          ),
          const ProdutoCard(
            nome: 'Frango',
            validade: 'Vence em 7 dias',
            data: '31/08/2026',
            cor: Color(0xFFF6A079),
          ),
          const ProdutoCard(
            nome: 'Arroz',
            validade: 'Vence em 120 dias',
            data: '15/12/2026',
            cor: Color(0xFFC8F5DF),
          ),
        ],
      ),
    );
  }
}

class ProdutoCard extends StatelessWidget {
  final String nome;
  final String validade;
  final String data;
  final Color cor;
  final bool urgente;

  const ProdutoCard({
    super.key,
    required this.nome,
    required this.validade,
    required this.data,
    required this.cor,
    this.urgente = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  validade,
                  style: TextStyle(
                    color: urgente ? Colors.red : verdeChefim,
                  ),
                ),
                Text(
                  data,
                  style: const TextStyle(
                    color: cinzaChefim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReceitasPage extends StatelessWidget {
  const ReceitasPage({super.key});

  @override
  Widget build(BuildContext context) {
    const receitas = [
      ['🍳', 'Omelete de Queijo', 'Queijo Mussarela, Ovos, Sal', '10 min'],
      ['🥤', 'Vitamina de Frutas', 'Leite, Banana, Mel', '5 min'],
      ['🍗', 'Frango Grelhado', 'Frango, Limão, Alho', '25 min'],
      ['🍚', 'Arroz com Frango', 'Arroz, Frango, Cebola', '35 min'],
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: Text(
              'Receitas',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Com o que você tem na despensa',
              style: TextStyle(color: cinzaChefim),
            ),
          ),
          const SizedBox(height: 25),
          ...receitas.map(
            (receita) => Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7EA),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      receita[0],
                      style: const TextStyle(fontSize: 25),
                    ),
                  ),
                  title: Text(
                    receita[1],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${receita[2]}\n⏱ ${receita[3]}',
                    style: const TextStyle(color: cinzaChefim),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Abrindo ${receita[1]}')),
                      );
                    },
                    child: const Text(
                      'Ver',
                      style: TextStyle(color: verdeChefim),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Perfil',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            ValueListenableBuilder<String?>(
              valueListenable: nomeUsuarioChefim,
              builder: (context, nome, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: emailUsuarioChefim,
                  builder: (context, email, _) {
                    final possuiConta = nome != null && nome.trim().isNotEmpty;
                    final nomePerfil = possuiConta ? nome! : 'Visitante';
                    final inicial = possuiConta
                        ? primeiroNome(nome!).substring(0, 1).toUpperCase()
                        : '?';

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: verdeChefim,
                          child: Text(
                            inicial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          nomePerfil,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          possuiConta
                              ? (email ?? '')
                              : 'Crie sua conta para salvar seus dados',
                          style: const TextStyle(color: cinzaChefim),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 1,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: const Text('Criar conta'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CriarContaPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title: const Text('Lista de compras'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListaComprasPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notificações'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Configurações'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 1,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Sobre o Chefim'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SobreChefimPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  nomeUsuarioChefim.value = null;
                  emailUsuarioChefim.value = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Você saiu da conta.'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sair da conta',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListaComprasPage extends StatefulWidget {
  const ListaComprasPage({super.key});

  @override
  State<ListaComprasPage> createState() => _ListaComprasPageState();
}

class _ListaComprasPageState extends State<ListaComprasPage> {
  final itemController = TextEditingController();
  final List<Map<String, dynamic>> itens = [];

  void adicionarItem() {
    final nomeItem = itemController.text.trim();
    if (nomeItem.isEmpty) return;

    setState(() {
      itens.add({'nome': nomeItem, 'comprado': false});
      itemController.clear();
    });
  }

  @override
  void dispose() {
    itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: verdeChefim,
        centerTitle: true,
        title: const Text(
          'Lista de compras',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => adicionarItem(),
                    decoration: InputDecoration(
                      hintText: 'Digite um produto',
                      filled: true,
                      fillColor: const Color(0xFFF6F7F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: adicionarItem,
                  style: IconButton.styleFrom(backgroundColor: verdeChefim),
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: itens.isEmpty
                  ? const Center(
                      child: Text(
                        'Sua lista está vazia.\nAdicione o primeiro produto!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cinzaChefim, height: 1.5),
                      ),
                    )
                  : ListView.separated(
                      itemCount: itens.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = itens[index];
                        final comprado = item['comprado'] as bool;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: comprado,
                            activeColor: verdeChefim,
                            onChanged: (valor) {
                              setState(() {
                                item['comprado'] = valor ?? false;
                              });
                            },
                          ),
                          title: Text(
                            item['nome'] as String,
                            style: TextStyle(
                              decoration: comprado
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: comprado ? cinzaChefim : Colors.black,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remover',
                            onPressed: () {
                              setState(() {
                                itens.removeAt(index);
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SobreChefimPage extends StatelessWidget {
  const SobreChefimPage({super.key});

  void abrirTermos(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Termos e Política de Privacidade'),
          content: const SingleChildScrollView(
            child: Text(
              'TERMOS DE USO\n\n'
              'O Chefim é um aplicativo acadêmico criado para auxiliar '
              'na organização de alimentos, controle de validade e '
              'sugestão de receitas.\n\n'
              'POLÍTICA DE PRIVACIDADE\n\n'
              'Os dados informados pelo usuário serão utilizados apenas '
              'para o funcionamento dos recursos do aplicativo, como '
              'cadastro, autenticação, produtos da despensa e alertas.\n\n'
              'As informações pessoais não devem ser compartilhadas '
              'indevidamente com terceiros.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Fechar',
                style: TextStyle(color: verdeChefim),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: verdeChefim,
                        size: 20,
                      ),
                    ),
                  ),
                  const Text(
                    'Sobre o Chefim',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Text(
                      'CHEFIM',
                      style: TextStyle(
                        color: verdeChefim,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Sua despensa inteligente',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'O Chefim ajuda você a organizar alimentos,\n'
                      'acompanhar validades e aproveitar melhor\n'
                      'suas compras.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cinzaChefim,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Como funciona?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const PassoSobre(
                numero: '1',
                titulo: 'Cadastre seus produtos',
                subtitulo: 'Registre alimentos e datas de validade.',
              ),
              const PassoSobre(
                numero: '2',
                titulo: 'Receba alertas',
                subtitulo: 'Saiba o que está perto de vencer.',
              ),
              const PassoSobre(
                numero: '3',
                titulo: 'Encontre receitas',
                subtitulo: 'Use seus ingredientes antes que estraguem.',
              ),
              const SizedBox(height: 20),
              const Text(
                'Projeto acadêmico',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sprint 2 — Engenharia de Computação\n'
                'Versão 1.0 • 2026',
                style: TextStyle(
                  color: cinzaChefim,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => abrirTermos(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: verdeChefim,
                    side: const BorderSide(color: verdeChefim),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Termos e Política de Privacidade',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class PassoSobre extends StatelessWidget {
  final String numero;
  final String titulo;
  final String subtitulo;

  const PassoSobre({
    super.key,
    required this.numero,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EA),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              numero,
              style: const TextStyle(
                color: verdeChefim,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    color: cinzaChefim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// SCANNER DE PRODUTOS
// ==========================================================

class ScannerProdutoPage extends StatefulWidget {
  const ScannerProdutoPage({super.key});

  @override
  State<ScannerProdutoPage> createState() => _ScannerProdutoPageState();
}

class _ScannerProdutoPageState extends State<ScannerProdutoPage> {
  final MobileScannerController controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );

  bool codigoEncontrado = false;

  Future<void> detectarCodigo(BarcodeCapture capture) async {
    if (codigoEncontrado || capture.barcodes.isEmpty) return;

    final valor = capture.barcodes.first.rawValue;

    if (valor == null || valor.isEmpty) return;

    codigoEncontrado = true;
    await controller.stop();

    if (!mounted) return;
    Navigator.pop(context, valor);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear produto'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Lanterna',
            onPressed: () => controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Trocar câmera',
            onPressed: () => controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: detectarCodigo,
          ),
          Center(
            child: Container(
              width: 285,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                  color: verdeChefim,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const Positioned(
            left: 28,
            right: 28,
            bottom: 80,
            child: Text(
              'Aponte a câmera para o código de barras do produto',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    blurRadius: 6,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
