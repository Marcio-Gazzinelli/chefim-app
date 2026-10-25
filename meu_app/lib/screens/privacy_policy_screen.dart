part of '../main.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => EntryPage(
    title: 'Política de Privacidade',
    builder: (pageContext, refresh) => [
      subtitle('Entenda como o protótipo utiliza e protege seus dados.'),
      _legalSection(
        icon: Icons.phone_android_outlined,
        title: 'Armazenamento local',
        text:
            'A conta, os produtos da despensa e os itens da lista de compras '
            'são armazenados somente neste dispositivo por meio do SQLite. '
            'As preferências do aplicativo, como tema e alertas, são '
            'salvas localmente com Shared Preferences.',
      ),
      _legalSection(
        icon: Icons.cloud_off_outlined,
        title: 'Envio de dados',
        text:
            'Na versão atual, o Chefim não envia os dados da despensa, '
            'da lista de compras ou das configurações para servidores '
            'externos.',
      ),
      _legalSection(
        icon: Icons.camera_alt_outlined,
        title: 'Uso da câmera',
        text:
            'A câmera é acessada somente com autorização do usuário '
            'para a leitura de códigos de barras. O protótipo não '
            'armazena fotos capturadas durante a leitura.',
      ),
      _legalSection(
        icon: Icons.account_circle_outlined,
        title: 'Cadastro e login',
        text:
            'A senha não é salva em texto legível: o aplicativo armazena '
            'somente um hash com salt para validar o login. Nesta versão, '
            'não existe conta remota, recuperação de senha nem sincronização '
            'entre dispositivos.',
      ),
      _legalSection(
        icon: Icons.delete_outline,
        title: 'Controle dos dados',
        text:
            'O usuário pode editar ou excluir os itens cadastrados. '
            'A desinstalação do aplicativo ou a limpeza dos dados pelo '
            'sistema pode apagar definitivamente as informações locais.',
      ),
      _legalSection(
        icon: Icons.policy_outlined,
        title: 'Atualizações da política',
        text:
            'Esta política será revisada antes da publicação do Chefim '
            'e sempre que forem adicionados serviços online ou novas formas '
            'de tratamento de dados.',
        last: true,
      ),
    ],
  );
}
