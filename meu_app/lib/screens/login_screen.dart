part of '../main.dart';

extension _LoginScreen on _ChefimShellState {
  Widget loginPage() {
    final mail = TextEditingController();
    final pass = TextEditingController();

    var submitting = false;
    var hidePassword = true;

    return EntryPage(
      title: 'Entrar',
      builder: (pageContext, refresh) => [
        const SizedBox(height: 12),
        Center(
          child: badge(Icons.lock_outline, softGreen, darkGreen, size: 52),
        ),
        const SizedBox(height: 11),
        Center(child: Text('Entre na sua conta', style: type(23, bold: true))),
        const SizedBox(height: 7),
        Center(
          child: Text(
            'Use a conta criada neste aparelho.',
            style: type(12, color: muted),
            textAlign: TextAlign.center,
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
        field(
          'Senha',
          'Digite sua senha',
          pass,
          hidden: hidePassword,
          onToggleVisibility: () {
            refresh(() {
              hidePassword = !hidePassword;
            });
          },
        ),
        const SizedBox(height: 18),
        primary(submitting ? 'Entrando...' : 'Entrar', () async {
          if (submitting) return;

          final normalizedEmail = mail.text.trim().toLowerCase();
          final password = pass.text;

          if (normalizedEmail.isEmpty || password.isEmpty) {
            ScaffoldMessenger.of(pageContext).showSnackBar(
              const SnackBar(content: Text('Informe o e-mail e a senha.')),
            );
            return;
          }

          refresh(() {
            submitting = true;
          });

          try {
            final user = await DatabaseService.instance.getUserByEmail(
              normalizedEmail,
            );

            final passwordIsCorrect =
                user != null &&
                PasswordService.verify(password, user.passwordHash);

            if (!passwordIsCorrect) {
              if (!pageContext.mounted) return;

              refresh(() {
                submitting = false;
              });

              ScaffoldMessenger.of(pageContext).showSnackBar(
                const SnackBar(content: Text('E-mail ou senha incorretos.')),
              );
              return;
            }

            await startUserSession(user);

            if (!pageContext.mounted) return;

            Navigator.pop(pageContext);
          } catch (_) {
            if (!pageContext.mounted) return;

            refresh(() {
              submitting = false;
            });

            ScaffoldMessenger.of(pageContext).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível entrar. Tente novamente.'),
              ),
            );
          }
        }),
        Center(
          child: TextButton(
            onPressed: submitting
                ? null
                : () {
                    Navigator.pushReplacement(
                      pageContext,
                      MaterialPageRoute(builder: (_) => registerPage()),
                    );
                  },
            child: const Text('Ainda não possui uma conta? Criar conta'),
          ),
        ),
      ],
    );
  }
}
