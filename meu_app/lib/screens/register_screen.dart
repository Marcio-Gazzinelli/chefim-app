part of '../main.dart';

extension _RegisterScreen on _ChefimShellState {
  Widget registerPage() {
    final person = TextEditingController();
    final mail = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();

    var submitting = false;
    var hidePassword = true;
    var hideConfirmation = true;

    return EntryPage(
      title: 'Criar conta',
      builder: (pageContext, refresh) => [
        const SizedBox(height: 12),
        Center(
          child: badge(Icons.person_outline, softGreen, darkGreen, size: 52),
        ),
        const SizedBox(height: 11),
        Center(
          child: Text('Comece a usar o Chefim', style: type(23, bold: true)),
        ),
        const SizedBox(height: 7),
        Center(
          child: Text(
            'Sua conta e seus dados serão salvos\n'
            'somente neste aparelho.',
            style: type(12, color: muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 22),
        field('Nome completo', 'Digite seu nome', person),
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
          'Mínimo de 8 caracteres',
          pass,
          hidden: hidePassword,
          onToggleVisibility: () {
            refresh(() {
              hidePassword = !hidePassword;
            });
          },
        ),
        const SizedBox(height: 14),
        field(
          'Confirmar senha',
          'Repita sua senha',
          confirm,
          hidden: hideConfirmation,
          onToggleVisibility: () {
            refresh(() {
              hideConfirmation = !hideConfirmation;
            });
          },
        ),
        const SizedBox(height: 16),
        primary(submitting ? 'Criando conta...' : 'Criar conta', () async {
          if (submitting) return;

          final fullName = person.text.trim();
          final normalizedEmail = mail.text.trim().toLowerCase();
          final password = pass.text;

          final emailIsValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
              .hasMatch(normalizedEmail);

          if (fullName.isEmpty ||
              !emailIsValid ||
              password.length < 8 ||
              password != confirm.text) {
            ScaffoldMessenger.of(pageContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'Confira nome, e-mail e senha '
                  '(mínimo de 8 caracteres).',
                ),
              ),
            );
            return;
          }

          refresh(() {
            submitting = true;
          });

          try {
            final emailAlreadyExists = await DatabaseService.instance
                .emailExists(normalizedEmail);

            if (emailAlreadyExists) {
              if (!pageContext.mounted) return;

              refresh(() {
                submitting = false;
              });

              ScaffoldMessenger.of(pageContext).showSnackBar(
                const SnackBar(
                  content: Text('Já existe uma conta com este e-mail.'),
                ),
              );
              return;
            }

            final passwordHash = PasswordService.hash(password);

            final user = await DatabaseService.instance.createUser(
              name: fullName,
              email: normalizedEmail,
              passwordHash: passwordHash,
            );

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
                content: Text(
                  'Não foi possível criar a conta. '
                  'Tente novamente.',
                ),
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
                      MaterialPageRoute(builder: (_) => loginPage()),
                    );
                  },
            child: const Text('Já possui uma conta? Entrar'),
          ),
        ),
      ],
    );
  }
}
