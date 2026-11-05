import 'package:flutter/material.dart';

/// Logotipo de Mi Voz (imagen 2 del proyecto: niño con audífonos, burbuja
/// con barras de sonido y el nombre "Mi Voz"). Ver `branding/`.
class MiVozLogo extends StatelessWidget {
  const MiVozLogo({super.key, this.size = 96});

  static const asset = 'assets/images/logo_mi_voz.png';

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logotipo de Mi Voz',
    image: true,
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );
}
