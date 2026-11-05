import 'package:flutter/material.dart';

import '../../../../core/visuals/avatar_catalog.dart';
import '../../../../core/widgets/visuals.dart';

/// Tipos de perfil al crear una cuenta, con sus colores suaves. Elegir uno
/// solo decide qué flujo de registro se abre: no da acceso a ninguna clase,
/// familia ni alumno.
enum AccessRole {
  teacher(
    label: 'Docente',
    description: 'Acompaño a mis alumnos en la escuela.',
    avatar: 'adult_long_black_glasses',
    badges: [Icons.menu_book_rounded, Icons.edit_rounded],
    background: Color(0xFFE3ECFF),
    accent: Color(0xFF2F5C93),
  ),
  guardian(
    label: 'Padre, madre o tutor',
    description: 'Acompaño a mis hijos o a niños a mi cargo.',
    avatar: 'adult_short_brown',
    badges: [Icons.favorite_rounded, Icons.home_rounded],
    background: Color(0xFFDFF3E8),
    accent: Color(0xFF256B4A),
  ),
  child(
    label: 'Alumno',
    description:
        'Perfil infantil con pictogramas. Lo crea un adulto responsable; '
        'no necesita correo.',
    avatar: 'animal_lion',
    badges: [Icons.chat_bubble_rounded, Icons.star_rounded],
    background: Color(0xFFFFF1D6),
    accent: Color(0xFFB4600F),
  );

  const AccessRole({
    required this.label,
    required this.description,
    required this.avatar,
    required this.badges,
    required this.background,
    required this.accent,
  });

  final String label;
  final String description;
  final String avatar;
  final List<IconData> badges;
  final Color background;
  final Color accent;
}

/// Ilustración sencilla: avatar del catálogo en un círculo pastel con dos
/// detalles de interfaz (sin sobrecarga visual).
class RoleIllustration extends StatelessWidget {
  const RoleIllustration({super.key, required this.role, this.size = 96});

  final AccessRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.32;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: role.background,
                  border: Border.all(
                    color: role.accent.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
                child: AvatarArtImage(
                  art: AvatarCatalog.byId(role.avatar)!,
                  size: size,
                ),
              ),
            ),
            Positioned(
              right: -size * 0.04,
              top: size * 0.02,
              child: _Badge(icon: role.badges[0], size: badge, role: role),
            ),
            Positioned(
              left: -size * 0.04,
              bottom: size * 0.02,
              child: _Badge(icon: role.badges[1], size: badge, role: role),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.size, required this.role});

  final IconData icon;
  final double size;
  final AccessRole role;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(icon, size: size * 0.55, color: role.accent),
  );
}
