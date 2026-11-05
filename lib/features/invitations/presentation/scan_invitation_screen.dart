import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/group_invitation.dart';

/// Escáner del QR de invitación. La cámara se solicita solo al abrir esta
/// pantalla. Si se deniega o no hay cámara, se vuelve a escribir el código.
/// Devuelve el código leído (nunca inicia sesión por sí mismo).
class ScanInvitationScreen extends StatefulWidget {
  const ScanInvitationScreen({super.key});

  @override
  State<ScanInvitationScreen> createState() => _ScanInvitationScreenState();
}

class _ScanInvitationScreenState extends State<ScanInvitationScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = InvitationLink.parse(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    setState(() => _hint = 'Este QR no es una invitación de Mi Voz.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear código QR')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _hint ?? 'Apunta la cámara al código QR de la invitación.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _hint == null ? AppColors.ink : AppColors.urgent,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Escribir el código'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'No se dio permiso para usar la cámara. Puedes escribir el código, o '
            'permitir la cámara en los ajustes del dispositivo.',
      MobileScannerErrorCode.unsupported =>
        'Este dispositivo no tiene una cámara disponible. Escribe el código.',
      _ => 'No se pudo abrir la cámara. Escribe el código.',
    };
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Escribir el código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
