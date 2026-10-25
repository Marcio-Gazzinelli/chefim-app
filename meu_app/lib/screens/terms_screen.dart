part of '../main.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => EntryPage(
    title: 'Termos de Uso',
    builder: (pageContext, refresh) => [
      subtitle('Conheça as condições de uso do protótipo Chefim.'),
      _legalSection(
        icon: Icons.school_outlined,
        title: 'Projeto acadêmico',
        text:
            'O Chefim é um protótipo acadêmico da PUC Minas, criado '
            'para demonstrar recursos de organização da despensa, '
            'controle de validade e sugestões de receitas.',
      ),
      _legalSection(
        icon: Icons.check_circle_outline,
        title: 'Uso do aplicativo',
        text:
            'Ao utilizar o Chefim, o usuário concorda em informar dados '
            'corretos sobre produtos, quantidades e datas de validade. '
            'O aplicativo serve como ferramenta de apoio à organização.',
      ),
      _legalSection(
        icon: Icons.restaurant_menu_outlined,
        title: 'Receitas e informações',
        text:
            'Receitas e informações alimentares exibidas no protótipo '
            'podem ser estimativas. O usuário deve verificar '
            'rótulos, restrições alimentares e condições dos alimentos.',
      ),
      _legalSection(
        icon: Icons.warning_amber_outlined,
        title: 'Responsabilidade',
        text:
            'O Chefim não substitui orientação médica, nutricional ou '
            'sanitária. A decisão de consumir ou descartar um alimento '
            'continua sendo responsabilidade do usuário.',
      ),
      _legalSection(
        icon: Icons.update_outlined,
        title: 'Alterações futuras',
        text:
            'Estes termos poderão ser atualizados conforme novas funções '
            'forem implementadas. Uma versão definitiva será disponibilizada '
            'antes da publicação comercial do aplicativo.',
        last: true,
      ),
    ],
  );
}

Widget _legalSection({
  required IconData icon,
  required String title,
  required String text,
  bool last = false,
}) => Padding(
  padding: EdgeInsets.only(bottom: last ? 0 : 12),
  child: panel(
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge(icon, softGreen, darkGreen, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: type(13, bold: true)),
              const SizedBox(height: 5),
              Text(text, style: type(11, color: muted)),
            ],
          ),
        ),
      ],
    ),
  ),
);
