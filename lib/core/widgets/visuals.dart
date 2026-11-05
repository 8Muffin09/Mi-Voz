import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../visuals/avatar_catalog.dart';
import '../visuals/symbol_catalog.dart';
import 'pictogram_card.dart' show EmojiGlyph;

/// Ilustración de un avatar del catálogo (sin fondo: lo pinta quien la usa).
class AvatarArtImage extends StatelessWidget {
  const AvatarArtImage({super.key, required this.art, required this.size});

  final AvatarArt art;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    art.asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

/// Pictograma ilustrado a partir del valor guardado (identificador del
/// catálogo o emoji heredado). Si no existe una ilustración equivalente se
/// conserva lo que el adulto eligió (el emoji original): nunca se pierde el
/// contenido de una frase.
class SymbolImage extends StatelessWidget {
  const SymbolImage(this.value, {super.key, this.size = 56, this.label});

  final String? value;
  final double size;

  /// Descripción accesible; si es `null` la imagen es decorativa (el texto
  /// junto a ella ya dice lo mismo).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final asset = SymbolCatalog.assetFor(value);
    final Widget image = asset != null
        ? Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _Missing(size: size),
          )
        : (value != null && value!.isNotEmpty && !_looksLikeId(value!))
        ? SizedBox.square(
            dimension: size,
            child: Center(child: EmojiGlyph(value!, size: size * 0.8)),
          )
        : _Missing(size: size);
    if (label == null) return ExcludeSemantics(child: image);
    return Semantics(image: true, label: label, child: image);
  }

  static bool _looksLikeId(String v) => RegExp(r'^[a-z0-9_]+$').hasMatch(v);
}

/// Pictograma sobre una ficha blanca redondeada: así todos los pictogramas
/// tienen el mismo encuadre y contraste sobre los colores de las categorías.
class SymbolFrame extends StatelessWidget {
  const SymbolFrame(this.value, {super.key, required this.size, this.label});

  final String? value;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.08),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.2),
    ),
    child: SymbolImage(value, size: size * 0.84, label: label),
  );
}

/// Intensidad ("Un poco", "Normal", "Mucho") como barras crecientes: se
/// entiende sin leer y no depende del color (cuenta las barras llenas).
class IntensityBars extends StatelessWidget {
  const IntensityBars({
    super.key,
    required this.level,
    required this.color,
    this.size = 26,
  });

  /// 1, 2 o 3.
  final int level;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 1; i <= 3; i++)
            Container(
              width: size * 0.26,
              height: size * (0.34 + 0.33 * (i - 1)),
              decoration: BoxDecoration(
                color: i <= level ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Ilustración de pantallas vacías ("Crea tu familia", "Niños vinculados",
/// "Aún no tienes alumnos"): avatares del catálogo agrupados, con el mismo
/// estilo que los perfiles reales.
class GroupIllustration extends StatelessWidget {
  const GroupIllustration._(this._members, {super.key});

  const GroupIllustration.family({Key? key})
    : this._(const [
        ('adult_long_brown', 0xFFDFF3E8),
        ('animal_bear', 0xFFFFE5B8),
        ('adult_short_black', 0xFFDCEBFF),
      ], key: key);

  const GroupIllustration.children({Key? key})
    : this._(const [
        ('animal_rabbit', 0xFFFFE1E6),
        ('animal_lion', 0xFFB8E0D2),
        ('animal_owl', 0xFFFFF1C9),
      ], key: key);

  const GroupIllustration.classroom({Key? key})
    : this._(const [
        ('animal_fox', 0xFFFFE5B8),
        ('adult_long_black_glasses', 0xFFDCEBFF),
        ('animal_panda', 0xFFEADFFF),
      ], key: key);

  final List<(String, int)> _members;

  @override
  Widget build(BuildContext context) {
    const small = 64.0;
    const big = 84.0;
    Widget bubble((String, int) m, double size) => Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color(m.$2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: AvatarArtImage(art: AvatarCatalog.byId(m.$1)!, size: size),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: small * 2 + big - 28,
        height: big,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(left: 0, bottom: 0, child: bubble(_members[0], small)),
            Positioned(right: 0, bottom: 0, child: bubble(_members[2], small)),
            bubble(_members[1], big),
          ],
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Icon(
      Icons.chat_bubble_outline_rounded,
      size: size * 0.7,
      color: Colors.black38,
    ),
  );
}
