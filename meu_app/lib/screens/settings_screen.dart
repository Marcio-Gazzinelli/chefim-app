part of '../main.dart';

extension _SettingsScreen on _ChefimShellState {
  Widget settingsPage(bool notifications) {
    return _SettingsPage(notifications: notifications);
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.notifications});

  final bool notifications;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final PreferencesService _preferences = PreferencesService.instance;

  bool _loading = true;

  bool _dataSaver = true;
  bool _automaticSync = true;
  bool _personalizedSuggestions = false;

  bool _expiryNotifications = true;
  bool _recipeNotifications = true;
  bool _shoppingNotifications = false;
  int _expiryWarningDays = 3;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final dataSaver = await _preferences.getDataSaver();
    final automaticSync = await _preferences.getAutomaticSync();
    final personalizedSuggestions = await _preferences
        .getPersonalizedSuggestions();

    final expiryNotifications = await _preferences.getExpiryNotifications();
    final recipeNotifications = await _preferences.getRecipeNotifications();
    final shoppingNotifications = await _preferences.getShoppingNotifications();
    final expiryWarningDays = await _preferences.getExpiryWarningDays();

    if (!mounted) return;

    setState(() {
      _dataSaver = dataSaver;
      _automaticSync = automaticSync;
      _personalizedSuggestions = personalizedSuggestions;

      _expiryNotifications = expiryNotifications;
      _recipeNotifications = recipeNotifications;
      _shoppingNotifications = shoppingNotifications;
      _expiryWarningDays = expiryWarningDays;

      _loading = false;
    });
  }

  Future<void> _changeNightMode(bool value) async {
    await _preferences.setNightMode(value);

    nightMode.value = value;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _changeDataSaver(bool value) async {
    setState(() => _dataSaver = value);
    await _preferences.setDataSaver(value);
  }

  Future<void> _changeAutomaticSync(bool value) async {
    setState(() => _automaticSync = value);
    await _preferences.setAutomaticSync(value);
  }

  Future<void> _changePersonalizedSuggestions(bool value) async {
    setState(() => _personalizedSuggestions = value);
    await _preferences.setPersonalizedSuggestions(value);
  }

  Future<void> _changeExpiryNotifications(bool value) async {
    setState(() => _expiryNotifications = value);
    await _preferences.setExpiryNotifications(value);
  }

  Future<void> _changeRecipeNotifications(bool value) async {
    setState(() => _recipeNotifications = value);
    await _preferences.setRecipeNotifications(value);
  }

  Future<void> _changeShoppingNotifications(bool value) async {
    setState(() => _shoppingNotifications = value);
    await _preferences.setShoppingNotifications(value);
  }

  Future<void> _changeExpiryWarningDays(int value) async {
    setState(() => _expiryWarningDays = value);
    await _preferences.setExpiryWarningDays(value);
  }

  Widget _settingSwitch({
    required String title,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: type(12)),
      value: value,
      activeTrackColor: green,
      onChanged: (newValue) async {
        await onChanged(newValue);
      },
    );
  }

  List<Widget> _generalSettings() {
    return [
      _settingSwitch(
        title: 'Modo noturno',
        value: nightMode.value,
        onChanged: _changeNightMode,
      ),
      _settingSwitch(
        title: 'Modo econômico de dados',
        value: _dataSaver,
        onChanged: _changeDataSaver,
      ),
      _settingSwitch(
        title: 'Sincronização automática',
        value: _automaticSync,
        onChanged: _changeAutomaticSync,
      ),
      _settingSwitch(
        title: 'Sugestões personalizadas',
        value: _personalizedSuggestions,
        onChanged: _changePersonalizedSuggestions,
      ),
    ];
  }

  List<Widget> _notificationSettings() {
    return [
      _settingSwitch(
        title: 'Produtos perto do vencimento',
        value: _expiryNotifications,
        onChanged: _changeExpiryNotifications,
      ),
      ListTile(
        enabled: _expiryNotifications,
        title: Text('Avisar com antecedência', style: type(12)),
        subtitle: Text(
          'Escolha quantos dias antes do vencimento.',
          style: type(11, color: muted),
        ),
        trailing: DropdownButton<int>(
          value: _expiryWarningDays,
          dropdownColor: surface,
          style: type(12),
          underline: const SizedBox.shrink(),
          items: const [1, 2, 3, 5, 7]
              .map(
                (days) => DropdownMenuItem<int>(
                  value: days,
                  child: Text(days == 1 ? '1 dia' : '$days dias'),
                ),
              )
              .toList(),
          onChanged: _expiryNotifications
              ? (days) async {
                  if (days == null) return;
                  await _changeExpiryWarningDays(days);
                }
              : null,
        ),
      ),
      _settingSwitch(
        title: 'Novas receitas disponíveis',
        value: _recipeNotifications,
        onChanged: _changeRecipeNotifications,
      ),
      _settingSwitch(
        title: 'Lembretes da lista de compras',
        value: _shoppingNotifications,
        onChanged: _changeShoppingNotifications,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return EntryPage(
      title: widget.notifications ? 'Notificações' : 'Configurações',
      builder: (_, _) {
        return [
          subtitle(
            widget.notifications
                ? 'Escolha os alertas que quer receber.'
                : 'Personalize sua experiência no Chefim.',
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: green)),
            )
          else
            panel(
              Column(
                children: widget.notifications
                    ? _notificationSettings()
                    : _generalSettings(),
              ),
              padding: EdgeInsets.zero,
            ),
        ];
      },
    );
  }
}
