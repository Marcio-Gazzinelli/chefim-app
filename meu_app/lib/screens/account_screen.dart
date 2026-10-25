part of '../main.dart';

extension _AccountScreen on _ChefimShellState {
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
    ],
  );
}
