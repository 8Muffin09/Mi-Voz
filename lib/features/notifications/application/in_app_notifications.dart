import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/id_generator.dart';

/// Aviso mostrado dentro de la app: notificación simulada (modo demo) o
/// notificación push recibida con la app abierta.
class InAppNotice {
  InAppNotice({
    required this.title,
    required this.body,
    required this.simulated,
    this.childId,
    this.requestId,
    this.urgent = false,
    this.recipientLabel,
  }) : id = newId(),
       createdAt = DateTime.now();

  final String id;
  final String title;
  final String body;

  /// `true` si es una notificación simulada del modo demostración.
  final bool simulated;
  final String? childId;
  final String? requestId;
  final bool urgent;
  final String? recipientLabel;
  final DateTime createdAt;
}

class InAppNotificationsNotifier extends Notifier<List<InAppNotice>> {
  @override
  List<InAppNotice> build() => const [];

  void show(InAppNotice notice) {
    state = [...state, notice].take(5).toList();
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clear() => state = const [];
}

final inAppNotificationsProvider =
    NotifierProvider<InAppNotificationsNotifier, List<InAppNotice>>(
      InAppNotificationsNotifier.new,
    );
