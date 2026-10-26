part of '../main.dart';

extension _AccountScreen on _ChefimShellState {
  Widget accountPage() {
    return EntryPage(
      title: 'Minha conta',
      builder: (pageContext, _) => [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.phone_android, size: 18, color: darkGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conta armazenada somente neste aparelho.',
                      style: type(11, color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _changePassword(pageContext),
            icon: const Icon(Icons.lock_reset_outlined),
            label: const Text('Alterar senha'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _deleteAccount(pageContext),
            style: OutlinedButton.styleFrom(
              foregroundColor: red,
              side: BorderSide(color: red),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir conta'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A exclusão remove permanentemente a conta e os dados associados '
          'salvos neste aparelho.',
          style: type(11, color: muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext pageContext) async {
    final userId = currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('Nenhuma conta está conectada.')),
      );
      return;
    }

    final changed = await showDialog<bool>(
      context: pageContext,
      barrierDismissible: false,
      builder: (_) {
        return _ChangePasswordDialog(userId: userId);
      },
    );

    if (changed == true && pageContext.mounted) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso.')),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext pageContext) async {
    final userId = currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('Nenhuma conta está conectada.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: pageContext,
      barrierDismissible: false,
      builder: (_) {
        return _DeleteAccountDialog(userId: userId);
      },
    );

    if (confirmed != true || !pageContext.mounted) {
      return;
    }

    try {
      await deleteCurrentAccount();

      if (!pageContext.mounted) return;

      Navigator.pop(pageContext);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta excluída com sucesso.')),
        );
      }
    } catch (_) {
      if (!pageContext.mounted) return;

      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível excluir a conta. '
            'Tente novamente.',
          ),
        ),
      );
    }
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.userId});

  final int userId;

  @override
  State<_ChangePasswordDialog> createState() {
    return _ChangePasswordDialogState();
  }
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _currentPassword = TextEditingController();

  final TextEditingController _newPassword = TextEditingController();

  final TextEditingController _confirmation = TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmation = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentValue = _currentPassword.text;
    final newValue = _newPassword.text;

    if (currentValue.isEmpty) {
      setState(() {
        _errorMessage = 'Informe sua senha atual.';
      });
      return;
    }

    if (newValue.length < 8) {
      setState(() {
        _errorMessage = 'A nova senha deve ter pelo menos 8 caracteres.';
      });
      return;
    }

    if (newValue != _confirmation.text) {
      setState(() {
        _errorMessage = 'A confirmação da nova senha não corresponde.';
      });
      return;
    }

    if (newValue == currentValue) {
      setState(() {
        _errorMessage = 'Escolha uma senha diferente da senha atual.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final user = await DatabaseService.instance.getUserById(widget.userId);

      final currentPasswordIsCorrect =
          user != null &&
          PasswordService.verify(currentValue, user.passwordHash);

      if (!currentPasswordIsCorrect) {
        if (!mounted) return;

        setState(() {
          _submitting = false;
          _errorMessage = 'A senha atual está incorreta.';
        });
        return;
      }

      final newPasswordHash = PasswordService.hash(newValue);

      await DatabaseService.instance.updateUserPassword(
        userId: widget.userId,
        passwordHash: newPasswordHash,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _errorMessage =
            'Não foi possível alterar a senha. '
            'Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar senha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirme sua senha atual e escolha '
              'uma nova senha.',
              style: type(12, color: muted),
            ),
            const SizedBox(height: 18),
            field(
              'Senha atual',
              'Digite sua senha atual',
              _currentPassword,
              hidden: _hideCurrentPassword,
              onToggleVisibility: () {
                setState(() {
                  _hideCurrentPassword = !_hideCurrentPassword;
                });
              },
            ),
            const SizedBox(height: 14),
            field(
              'Nova senha',
              'Mínimo de 8 caracteres',
              _newPassword,
              hidden: _hideNewPassword,
              onToggleVisibility: () {
                setState(() {
                  _hideNewPassword = !_hideNewPassword;
                });
              },
            ),
            const SizedBox(height: 14),
            field(
              'Confirmar nova senha',
              'Digite novamente',
              _confirmation,
              hidden: _hideConfirmation,
              onToggleVisibility: () {
                setState(() {
                  _hideConfirmation = !_hideConfirmation;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: type(11, color: red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Salvando...' : 'Salvar senha'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.userId});

  final int userId;

  @override
  State<_DeleteAccountDialog> createState() {
    return _DeleteAccountDialogState();
  }
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();

  bool _hidePassword = true;
  bool _checking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_password.text.isEmpty) {
      setState(() {
        _errorMessage = 'Digite sua senha para confirmar a exclusão.';
      });
      return;
    }

    setState(() {
      _checking = true;
      _errorMessage = null;
    });

    try {
      final user = await DatabaseService.instance.getUserById(widget.userId);

      final passwordIsCorrect =
          user != null &&
          PasswordService.verify(_password.text, user.passwordHash);

      if (!passwordIsCorrect) {
        if (!mounted) return;

        setState(() {
          _checking = false;
          _errorMessage = 'A senha informada está incorreta.';
        });
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _checking = false;
        _errorMessage = 'Não foi possível confirmar sua senha.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Excluir conta?', style: TextStyle(color: red)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação excluirá permanentemente sua '
              'conta, os produtos da despensa e os itens '
              'da lista de compras salvos neste aparelho. '
              'Não será possível desfazer.',
            ),
            const SizedBox(height: 18),
            field(
              'Confirme sua senha',
              'Digite sua senha',
              _password,
              hidden: _hidePassword,
              onToggleVisibility: () {
                setState(() {
                  _hidePassword = !_hidePassword;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: type(11, color: red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _checking ? null : _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
          ),
          child: Text(_checking ? 'Confirmando...' : 'Excluir conta'),
        ),
      ],
    );
  }
}
