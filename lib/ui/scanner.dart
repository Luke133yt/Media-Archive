import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'glass.dart';

bool get _cameraScanSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Apre lo scanner con la fotocamera (Android, iOS, macOS, web).
/// Su Windows/Linux apre un campo di testo: funziona anche con i lettori
/// di codici a barre USB, che si comportano come una tastiera.
Future<String?> scanBarcode(BuildContext context) async {
  if (_cameraScanSupported) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
  }
  return _manualEntry(context);
}

Future<String?> _manualEntry(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Codice a barre'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          'Digita il codice oppure usa un lettore USB: premi qui e scansiona.',
          style: TextStyle(color: adaptiveTextColor(context, opacity: .7)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'EAN / UPC'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Scansiona il codice a barre')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_done) return;
              final code = capture.barcodes
                  .map((b) => b.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (code != null && code.isNotEmpty) {
                _done = true;
                Navigator.of(context).pop(code);
              }
            },
            errorBuilder: (context, error, child) => Center(
              child: GlassCard(
                child: Text(
                  'Impossibile usare la fotocamera.\n${error.errorCode.name}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: IconButton.filledTonal(
                onPressed: () => _controller.toggleTorch(),
                icon: const Icon(Icons.flashlight_on),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
