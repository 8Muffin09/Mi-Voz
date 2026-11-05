import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../models/app_user.dart';
import '../../models/child_profile.dart';
import '../visuals/avatar_catalog.dart';
import 'visuals.dart';

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.child, this.size = 48});

  final ChildProfile child;
  final double size;

  @override
  Widget build(BuildContext context) => AvatarBubble(
    avatar: child.avatar,
    fallback: AvatarCatalog.defaultChild,
    color: Color(child.avatarColor),
    photo: child.photo,
    size: size,
    semanticLabel: 'Avatar de ${child.name}',
  );
}

/// Avatar de un adulto (ilustración del perfil o foto).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 48});

  final AppUser user;
  final double size;

  @override
  Widget build(BuildContext context) => AvatarBubble(
    avatar: user.avatarRef,
    fallback: AvatarCatalog.defaultAdult,
    color: Color(user.avatarColorValue),
    photo: user.photo,
    size: size,
    semanticLabel: 'Avatar de ${user.firstName}',
  );
}

/// Círculo con el avatar ilustrado sobre el color del perfil o, si hay una
/// foto disponible, la foto. Mientras la foto carga (o si no se puede leer)
/// se muestra la ilustración.
class AvatarBubble extends ConsumerWidget {
  const AvatarBubble({
    super.key,
    required this.avatar,
    required this.color,
    this.fallback = AvatarCatalog.defaultChild,
    this.photo,
    this.size = 48,
    this.semanticLabel,
  });

  /// Identificador del catálogo (o emoji heredado).
  final String? avatar;
  final String fallback;
  final Color color;
  final String? photo;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoRef = photo;
    final bytes = photoRef == null
        ? null
        : ref.watch(photoBytesProvider(photoRef)).value;
    final art = AvatarCatalog.resolve(avatar) ?? AvatarCatalog.byId(fallback)!;
    final illustration = AvatarArtImage(art: art, size: size);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: bytes != null
            ? Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => illustration,
              )
            : illustration,
      ),
    );
  }
}
