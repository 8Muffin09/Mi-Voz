import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../visuals/avatar_catalog.dart';
import 'child_avatar.dart';
import 'dialogs.dart';
import 'visuals.dart';

/// Abre la galería y devuelve la foto elegida (reducida para el avatar).
Future<File?> pickAvatarPhoto(BuildContext context) async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    return file == null ? null : File(file.path);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'No se pudo abrir la galería.', error: true);
    }
    return null;
  }
}

/// Selector de avatar: vista previa con la foto opcional al lado, galería
/// ordenada por grupos y color de fondo. La selección se marca con un borde
/// grueso y una palomita (no solo con color) y se anuncia al lector de
/// pantalla. El estado lo guarda la pantalla que lo usa.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.avatar,
    required this.color,
    required this.options,
    required this.colorOptions,
    required this.onAvatar,
    required this.onColor,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    this.existingPhoto,
    this.newPhoto,
    this.photoHelp = 'La fotografía es opcional: puedes usar solo el avatar.',
  });

  /// Identificador del avatar elegido (o valor heredado).
  final String avatar;
  final int color;
  final List<AvatarArt> options;
  final List<int> colorOptions;
  final ValueChanged<String> onAvatar;
  final ValueChanged<int> onColor;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;

  /// Foto ya guardada en el perfil (referencia de `PhotoStore`).
  final String? existingPhoto;

  /// Foto recién elegida, aún sin guardar.
  final File? newPhoto;
  final String photoHelp;

  bool get _hasPhoto => newPhoto != null || existingPhoto != null;

  @override
  Widget build(BuildContext context) {
    const previewSize = 96.0;
    final selectedId = AvatarCatalog.resolve(avatar)?.id;
    final photo = newPhoto;
    final groups = <AvatarGroup, List<AvatarArt>>{};
    for (final a in options) {
      (groups[a.group] ??= []).add(a);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            photo != null
                ? ClipOval(
                    child: Image.file(
                      photo,
                      key: const Key('avatar-new-photo'),
                      width: previewSize,
                      height: previewSize,
                      fit: BoxFit.cover,
                    ),
                  )
                : AvatarBubble(
                    key: const Key('avatar-preview'),
                    avatar: avatar,
                    fallback: options.first.id,
                    color: Color(color),
                    photo: existingPhoto,
                    size: previewSize,
                    semanticLabel: 'Vista previa del avatar',
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    key: const Key('avatar-pick-photo'),
                    onPressed: onPickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _hasPhoto ? 'Cambiar fotografía' : 'Elegir fotografía',
                    ),
                  ),
                  if (_hasPhoto)
                    TextButton.icon(
                      key: const Key('avatar-remove-photo'),
                      onPressed: onRemovePhoto,
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('Usar solo el avatar'),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    photoHelp,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        for (final entry in groups.entries) ...[
          const SizedBox(height: 14),
          Text(
            entry.key.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Celdas de 56–72 px que llenan el ancho disponible.
              final columns = (constraints.maxWidth / 64).floor().clamp(4, 10);
              final cell = (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in entry.value)
                    _AvatarOption(
                      art: a,
                      size: cell,
                      color: Color(color),
                      selected: a.id == selectedId && !_hasPhoto,
                      onTap: () => onAvatar(a.id),
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 14),
        const Text(
          'Color de fondo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, c) in colorOptions.indexed)
              _ColorOption(
                color: Color(c),
                index: i + 1,
                selected: c == color,
                onTap: () => onColor(c),
              ),
          ],
        ),
      ],
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.art,
    required this.size,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final AvatarArt art;
  final double size;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: art.label,
    excludeSemantics: true,
    child: Tooltip(
      message: art.label,
      child: InkWell(
        key: Key('avatar-option-${art.id}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.all(selected ? 3 : 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.ink : Colors.black12,
                      width: selected ? 3.5 : 1,
                    ),
                  ),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: AvatarArtImage(art: art, size: size),
                  ),
                ),
              ),
              if (selected)
                const Positioned(right: -2, bottom: -2, child: _CheckBadge()),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Color de fondo $index',
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: AppColors.ink, size: 22)
            : null,
      ),
    ),
  );
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: const BoxDecoration(
      color: AppColors.ink,
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
  );
}
