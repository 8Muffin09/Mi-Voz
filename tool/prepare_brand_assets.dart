// Prepara los recursos gráficos de Mi Voz a partir de las imágenes originales
// de `branding/` (no se modifican). Uso:
//
//   dart run tool/prepare_brand_assets.dart
//   dart run flutter_launcher_icons
//
// Genera:
// - assets/images/splash_mi_voz.png      Imagen 1 con el exterior del círculo
//                                        transparente (para el fondo suave).
// - assets/images/logo_mi_voz.png        Imagen 2 recortada, fondo transparente.
// - assets/icon/app_icon.png             Icono completo (iOS y Android < 8).
// - assets/icon/app_icon_foreground.png  Primer plano del icono adaptativo,
//                                        dentro de la zona segura (64 %).
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const splashSource = 'branding/imagen1_pantalla_de_carga.png';
const iconSource = 'branding/imagen2_icono_app.png';

/// Fondo del icono adaptativo (mismo valor que en pubspec.yaml).
const iconBackground = 0xFFE3F1FF;

void main() {
  _splash();
  final art = _iconArt();
  _write('assets/images/logo_mi_voz.png', _fit(art, 512, 1.0));
  _write('assets/icon/app_icon_foreground.png', _fit(art, 1024, 0.64));
  _write('assets/icon/app_icon.png', _fullIcon(art));
  stdout.writeln('Recursos generados.');
}

/// Imagen 1: lo que está fuera del marco circular es blanco; se convierte en
/// transparencia ("color a alfa") para que el fondo de la pantalla se vea.
void _splash() {
  final src = img.decodePng(File(splashSource).readAsBytesSync())!;
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  final cx = src.width / 2;
  final cy = src.height / 2;
  final opaqueRadius = src.width * 0.45;
  for (final p in src) {
    final d = math.sqrt(math.pow(p.x - cx, 2) + math.pow(p.y - cy, 2));
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();
    if (d < opaqueRadius) {
      out.setPixelRgba(p.x, p.y, r, g, b, 255);
      continue;
    }
    // Cuánto se separa del blanco el canal más claro.
    final distance = 255 - math.min(r, math.min(g, b));
    final alpha = ((distance - 3) / 37).clamp(0.0, 1.0);
    if (alpha == 0) {
      out.setPixelRgba(p.x, p.y, 255, 255, 255, 0);
      continue;
    }
    // Quita la mezcla con el blanco para que el borde no quede gris.
    double unblend(double c) => ((c - 255 * (1 - alpha)) / alpha).clamp(0, 255);
    out.setPixelRgba(
      p.x,
      p.y,
      unblend(r),
      unblend(g),
      unblend(b),
      (alpha * 255).round(),
    );
  }
  _write(
    'assets/images/splash_mi_voz.png',
    img.copyResize(
      out,
      width: 1024,
      height: 1024,
      interpolation: img.Interpolation.average,
    ),
  );
}

/// Imagen 2 recortada a su contenido. Los píxeles casi transparentes tienen
/// colores residuales que se limpian para que no "manchen" al escalar.
img.Image _iconArt() {
  final src = img.decodePng(File(iconSource).readAsBytesSync())!;
  var minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (final p in src) {
    if (p.a < 16) {
      p
        ..r = 255
        ..g = 255
        ..b = 255
        ..a = 0;
      continue;
    }
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

/// Centra [art] en un lienzo cuadrado transparente ocupando [scale] del lado.
img.Image _fit(img.Image art, int size, double scale) {
  final box = size * scale;
  final factor = math.min(box / art.width, box / art.height);
  final resized = img.copyResize(
    art,
    width: (art.width * factor).round(),
    height: (art.height * factor).round(),
    interpolation: img.Interpolation.average,
  );
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 0));
  img.compositeImage(
    canvas,
    resized,
    dstX: (size - resized.width) ~/ 2,
    dstY: (size - resized.height) ~/ 2,
  );
  return canvas;
}

/// Icono sin transparencia: fondo celeste suave con un brillo central.
img.Image _fullIcon(img.Image art) {
  const size = 1024;
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  final base = img.ColorRgb8(
    (iconBackground >> 16) & 255,
    (iconBackground >> 8) & 255,
    iconBackground & 255,
  );
  for (final p in canvas) {
    final d = math.sqrt(
      math.pow(p.x - size / 2, 2) + math.pow(p.y - size / 2, 2),
    );
    final t = (1 - d / (size * 0.72)).clamp(0.0, 1.0) * 0.55;
    p
      ..r = base.r + (255 - base.r) * t
      ..g = base.g + (255 - base.g) * t
      ..b = base.b + (255 - base.b) * t;
  }
  img.compositeImage(canvas, _fit(art, size, 0.86));
  return canvas;
}

void _write(String path, img.Image image) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image, level: 9));
  stdout.writeln('  $path (${image.width}x${image.height})');
}
