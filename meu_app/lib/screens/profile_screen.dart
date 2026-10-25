part of '../main.dart';

extension _ProfileScreen on _ChefimShellState {
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
                ? const Icon(Icons.person_outline, color: Colors.white)
                : Text(
                    name![0].toUpperCase(),
                    style: type(21, bold: true, color: Colors.white),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name ?? 'Visitante', style: type(15, bold: true)),
                const SizedBox(height: 4),
                Text(
                  email ?? 'Crie sua conta para salvar seus dados',
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
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text('SUA CONTA', style: type(10, bold: true, color: darkGreen)),
    ),
    panel(
      Column(
        children: [
          if (name == null) ...[
            menu(
              'Criar conta',
              Icons.person_add_alt_1_outlined,
              () => open(registerPage()),
            ),
            menu('Entrar', Icons.login, () => open(loginPage())),
          ] else
            menu(
              'Minha conta',
              Icons.person_outline,
              () => open(accountPage()),
            ),
          menu(
            'Lista de compras',
            Icons.shopping_cart_outlined,
            () => open(ShoppingListPage(userId: currentUserId)),
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
          onPressed: _confirmSignOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: red,
            side: BorderSide(color: red),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
        ),
      ),
  ]);

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Sua conta continuará salva neste aparelho e você poderá entrar '
          'novamente com seu e-mail e senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await endUserSession();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível sair da conta.')),
      );
    }
  }

  Widget menu(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool last = false,
  }) => Column(
    children: [
      ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: badge(icon, softGreen, darkGreen),
        title: Text(label, style: type(12)),
        trailing: Icon(Icons.chevron_right, color: muted),
      ),
      if (!last) Divider(height: 1, color: line),
    ],
  );
}
