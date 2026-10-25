part of '../main.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final camera = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );

  bool found = false;

  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  Future<void> detected(BarcodeCapture data) async {
    if (found || data.barcodes.isEmpty) return;

    final code = data.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    found = true;
    await camera.stop();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Produto escaneado'),
        content: Text('Código identificado com sucesso\n\n$code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );

    if (mounted) {
      found = false;
      await camera.start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B100C),
    body: SafeArea(
      child: Stack(
        children: [
          MobileScanner(controller: camera, onDetect: detected),
          Positioned(
            top: 2,
            left: 10,
            right: 10,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Escanear produto',
                    textAlign: TextAlign.center,
                    style: type(18, bold: true, color: Colors.white),
                  ),
                ),
                IconButton(
                  onPressed: () => camera.toggleTorch(),
                  icon: const Icon(
                    Icons.flash_on_outlined,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => camera.switchCamera(),
                  icon: const Icon(
                    Icons.cameraswitch_outlined,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 266,
              height: 188,
              decoration: BoxDecoration(
                border: Border.all(color: green, width: 3),
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
          Positioned(
            bottom: 55,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, color: green, size: 35),
                const SizedBox(height: 11),
                Text(
                  'Aponte a câmera para o\n'
                  'código de barras do produto',
                  textAlign: TextAlign.center,
                  style: type(13, bold: true, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
