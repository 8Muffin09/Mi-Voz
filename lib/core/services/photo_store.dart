import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Fotos de perfil opcionales (adultos y niños).
///
/// La referencia que se guarda en el perfil indica dónde está la foto:
/// - `file:<ruta>`: copia local en el dispositivo (modo demostración).
/// - `storage:<ruta>`: Firebase Storage. Se descarga con [load], que pasa por
///   las reglas de seguridad; no se usan enlaces públicos de descarga.
abstract class PhotoStore {
  static const filePrefix = 'file:';
  static const storagePrefix = 'storage:';
  static const maxBytes = 5 * 1024 * 1024;

  /// Guarda [file] y devuelve la referencia para el perfil.
  Future<String> save({required String storagePath, required File file});

  Future<Uint8List?> load(String photo);

  Future<void> delete(String? photo);

  static Future<Uint8List?> loadLocal(String photo) async {
    if (!photo.startsWith(filePrefix)) return null;
    final file = File(photo.substring(filePrefix.length));
    return await file.exists() ? file.readAsBytes() : null;
  }
}

/// Copia las fotos a la carpeta privada de la app.
class LocalPhotoStore implements PhotoStore {
  const LocalPhotoStore();

  @override
  Future<String> save({required String storagePath, required File file}) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/avatars');
    await folder.create(recursive: true);
    // Nombre nuevo en cada cambio para que no se muestre la foto anterior.
    final name = storagePath.replaceAll(RegExp('[^A-Za-z0-9]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final copy = await file.copy('${folder.path}/${name}_$stamp.jpg');
    return '${PhotoStore.filePrefix}${copy.path}';
  }

  @override
  Future<Uint8List?> load(String photo) => PhotoStore.loadLocal(photo);

  @override
  Future<void> delete(String? photo) async {
    if (photo == null || !photo.startsWith(PhotoStore.filePrefix)) return;
    final file = File(photo.substring(PhotoStore.filePrefix.length));
    if (await file.exists()) await file.delete();
  }
}

/// Fotos en Firebase Storage (requiere el plan Blaze para buckets nuevos).
class FirebasePhotoStore implements PhotoStore {
  FirebasePhotoStore(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> save({required String storagePath, required File file}) async {
    await _storage
        .ref(storagePath)
        .putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final stamp = DateTime.now().millisecondsSinceEpoch;
    // El sufijo cambia la referencia para que las pantallas recarguen la foto.
    return '${PhotoStore.storagePrefix}$storagePath#$stamp';
  }

  @override
  Future<Uint8List?> load(String photo) async {
    if (photo.startsWith(PhotoStore.filePrefix)) {
      return PhotoStore.loadLocal(photo);
    }
    if (!photo.startsWith(PhotoStore.storagePrefix)) return null;
    final path = photo
        .substring(PhotoStore.storagePrefix.length)
        .split('#')
        .first;
    try {
      return await _storage.ref(path).getData(PhotoStore.maxBytes);
    } on FirebaseException {
      // Sin permiso, sin conexión o foto eliminada: se usa el avatar.
      return null;
    }
  }

  @override
  Future<void> delete(String? photo) async {
    if (photo == null || !photo.startsWith(PhotoStore.storagePrefix)) return;
    final path = photo
        .substring(PhotoStore.storagePrefix.length)
        .split('#')
        .first;
    try {
      await _storage.ref(path).delete();
    } on FirebaseException {
      // Ya no existe.
    }
  }
}
