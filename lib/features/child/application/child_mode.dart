import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';

/// Perfil infantil activo en "modo niño" en este dispositivo.
///
/// Se guarda en el dispositivo: si la app se reinicia sigue en modo niño,
/// y solo se sale tras superar la verificación de adulto.
class ChildModeNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(localStoreProvider).getString(LocalStore.keyChildMode);

  Future<void> enter(String childId) async {
    await ref
        .read(localStoreProvider)
        .setString(LocalStore.keyChildMode, childId);
    state = childId;
  }

  Future<void> exit() async {
    await ref.read(localStoreProvider).remove(LocalStore.keyChildMode);
    state = null;
  }
}

final childModeProvider = NotifierProvider<ChildModeNotifier, String?>(
  ChildModeNotifier.new,
);
