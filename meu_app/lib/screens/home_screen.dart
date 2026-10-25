part of '../main.dart';

extension _HomeScreen on _ChefimShellState {
  Widget home() {
    final expired = products.where((product) => product.days < 0).length;
    final expiring = products
        .where((product) => product.days >= 0 && product.days <= 3)
        .length;
    final hasAttention = expired > 0 || expiring > 0;

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
                  TextSpan(text: '.', style: type(23, bold: true)),
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
      Text('Que bom ter você por aqui!', style: type(14, color: muted)),
      const SizedBox(height: 17),
      panel(
        Container(
          constraints: const BoxConstraints(minHeight: 176),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [attentionStart, attentionEnd]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasAttention) ...[
                      Text(
                        'ATENÇÃO',
                        style: type(10, bold: true, color: darkGreen),
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(
                      expired > 0
                          ? 'Há produtos vencidos na despensa.'
                          : expiring > 0
                          ? 'Consuma antes, desperdice menos.'
                          : 'Tudo em dia!',
                      style: type(17, bold: true),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      expired > 0
                          ? 'Você tem $expired produto'
                                '${expired == 1 ? '' : 's'} vencido'
                                '${expired == 1 ? '' : 's'}.'
                          : expiring > 0
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
                  Icon(Icons.calendar_month_outlined, color: green, size: 51),
                  if (hasAttention)
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
                          style: type(16, bold: true, color: Colors.white),
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
              productsLoading ? '...' : '${products.length}',
              'Produtos cadastrados',
              Icons.inventory_2_outlined,
              softGreen,
              darkGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: stat(
              productsLoading ? '...' : '$expiring',
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
              productsLoading ? '...' : '$expired',
              'Produtos vencidos',
              Icons.event_busy_outlined,
              rose,
              red,
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

  Widget stat(String value, String label, IconData icon, Color bg, Color fg) =>
      panel(
        SizedBox(
          height: 125,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badge(icon, bg, fg),
              const SizedBox(height: 8),
              Text(value, style: type(22, bold: true)),
              Text(label, maxLines: 2, style: type(11, color: muted)),
            ],
          ),
        ),
      );
}
