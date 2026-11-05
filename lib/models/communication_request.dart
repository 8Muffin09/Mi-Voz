import '../core/utils/json_utils.dart';

/// Estado de atención de la solicitud (lo cambian los adultos).
enum RequestStatus {
  newRequest('Nueva'),
  seen('Vista'),
  attending('Atendiendo'),
  resolved('Resuelta');

  const RequestStatus(this.label);
  final String label;

  /// Nombre guardado en la base de datos.
  String get key => this == RequestStatus.newRequest ? 'new' : name;

  static RequestStatus fromKey(Object? key) {
    if (key == 'new') return RequestStatus.newRequest;
    return enumByName(RequestStatus.values, key, RequestStatus.newRequest);
  }

  bool get isOpen => this != RequestStatus.resolved;
}

enum RequestPriority {
  normal('Normal'),
  high('Alta');

  const RequestPriority(this.label);
  final String label;
}

/// Entrega de la solicitud al servidor (o a la base local en demostración).
enum DeliveryStatus {
  /// Guardada en el dispositivo, aún sin confirmar en el servidor.
  pendingSync('Pendiente de envío'),

  /// Confirmada por el servidor.
  delivered('Enviada');

  const DeliveryStatus(this.label);
  final String label;
}

/// Resultado del envío de la notificación push (lo escribe el backend).
/// "Enviada" significa que el servicio de notificaciones la aceptó, no que
/// alguien la haya leído: eso lo indica el estado de atención.
enum NotificationStatus {
  pending('Notificación en proceso'),
  sent('Aviso enviado'),
  noRecipients('Nadie configurado para recibir el aviso'),
  noDevices('Ningún dispositivo para avisar'),
  failed('No se pudo enviar el aviso'),
  simulated('Aviso simulado (solo en este dispositivo)');

  const NotificationStatus(this.label);
  final String label;

  /// El aviso no salió hacia ningún adulto.
  bool get reachedNobody =>
      this == noRecipients || this == noDevices || this == failed;
}

/// Por qué se avisó a esos adultos (lo escribe el backend).
enum NotificationRoute {
  companion('Quien acompaña'),
  rule('Regla "si nadie acompaña"'),
  ruleAfterCompanion(
    'Regla "si nadie acompaña" (quien acompaña no tenía dispositivos)',
  );

  const NotificationRoute(this.label);
  final String label;
}

class CommunicationRequest {
  const CommunicationRequest({
    required this.id,
    required this.childId,
    required this.childName,
    required this.categoryId,
    required this.categoryTitle,
    required this.message,
    required this.emoji,
    required this.priority,
    required this.createdByUid,
    required this.createdAt,
    this.pictogramIds = const [],
    this.isUrgent = false,
    this.recipientUid,
    this.recipientName,
    this.status = RequestStatus.newRequest,
    this.statusUpdatedAt,
    this.statusUpdatedByUid,
    this.statusUpdatedByName,
    this.seenAt,
    this.attendingAt,
    this.resolvedAt,
    this.note,
    this.delivery = DeliveryStatus.pendingSync,
    this.deliveredAt,
    this.notification = NotificationStatus.pending,
    this.notifiedAt,
    this.notifiedNames = const [],
    this.notifiedUids = const [],
    this.route,
  });

  final String id;
  final String childId;
  final String childName;
  final String categoryId;
  final String categoryTitle;
  final String message;
  final String emoji;
  final List<String> pictogramIds;
  final RequestPriority priority;
  final bool isUrgent;

  /// Adulto responsable en el momento de crear la solicitud.
  final String? recipientUid;
  final String? recipientName;
  final String createdByUid;
  final DateTime createdAt;

  final RequestStatus status;
  final DateTime? statusUpdatedAt;
  final String? statusUpdatedByUid;
  final String? statusUpdatedByName;
  final DateTime? seenAt;
  final DateTime? attendingAt;
  final DateTime? resolvedAt;
  final String? note;

  // Estos campos no se guardan desde el cliente: los calcula la app
  // (entrega) o el backend (notificación).
  final DeliveryStatus delivery;
  final DateTime? deliveredAt;
  final NotificationStatus notification;
  final DateTime? notifiedAt;
  final List<String> notifiedNames;
  final List<String> notifiedUids;
  final NotificationRoute? route;

  /// A quién iba dirigida: quien acompañaba o, si nadie, los avisados.
  String get recipientLabel =>
      recipientName ??
      (notifiedNames.isEmpty
          ? 'Sin acompañante'
          : 'Sin acompañante: ${notifiedNames.join(', ')}');

  /// Texto de la notificación: "Juan necesita atención: Me molesta el ruido".
  String get notificationTitle => isUrgent
      ? '🆘 $childName necesita ayuda urgente'
      : '$childName necesita atención';

  CommunicationRequest copyWith({
    RequestStatus? status,
    DateTime? statusUpdatedAt,
    String? statusUpdatedByUid,
    String? statusUpdatedByName,
    DateTime? seenAt,
    DateTime? attendingAt,
    DateTime? resolvedAt,
    String? note,
    DeliveryStatus? delivery,
    DateTime? deliveredAt,
    NotificationStatus? notification,
    DateTime? notifiedAt,
    List<String>? notifiedNames,
    List<String>? notifiedUids,
    NotificationRoute? route,
  }) => CommunicationRequest(
    id: id,
    childId: childId,
    childName: childName,
    categoryId: categoryId,
    categoryTitle: categoryTitle,
    message: message,
    emoji: emoji,
    pictogramIds: pictogramIds,
    priority: priority,
    isUrgent: isUrgent,
    recipientUid: recipientUid,
    recipientName: recipientName,
    createdByUid: createdByUid,
    createdAt: createdAt,
    status: status ?? this.status,
    statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
    statusUpdatedByUid: statusUpdatedByUid ?? this.statusUpdatedByUid,
    statusUpdatedByName: statusUpdatedByName ?? this.statusUpdatedByName,
    seenAt: seenAt ?? this.seenAt,
    attendingAt: attendingAt ?? this.attendingAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    note: note ?? this.note,
    delivery: delivery ?? this.delivery,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    notification: notification ?? this.notification,
    notifiedAt: notifiedAt ?? this.notifiedAt,
    notifiedNames: notifiedNames ?? this.notifiedNames,
    notifiedUids: notifiedUids ?? this.notifiedUids,
    route: route ?? this.route,
  );

  /// Campos que crea el cliente (lo que permiten las reglas de Firestore).
  Map<String, dynamic> toCreateMap() => {
    'id': id,
    'childId': childId,
    'childName': childName,
    'categoryId': categoryId,
    'categoryTitle': categoryTitle,
    'message': message,
    'emoji': emoji,
    'pictogramIds': pictogramIds,
    'priority': priority.name,
    'isUrgent': isUrgent,
    'recipientUid': recipientUid,
    'recipientName': recipientName,
    'createdByUid': createdByUid,
    'createdAt': createdAt,
    'status': RequestStatus.newRequest.key,
  };

  /// Representación completa (almacenamiento local y modo demostración).
  Map<String, dynamic> toMap() => {
    ...toCreateMap(),
    'status': status.key,
    'statusUpdatedAt': statusUpdatedAt,
    'statusUpdatedByUid': statusUpdatedByUid,
    'statusUpdatedByName': statusUpdatedByName,
    'seenAt': seenAt,
    'attendingAt': attendingAt,
    'resolvedAt': resolvedAt,
    'note': note,
    'delivery': delivery.name,
    'deliveredAt': deliveredAt,
    'notification': {
      'status': notification.name,
      'sentAt': notifiedAt,
      'recipientNames': notifiedNames,
      'recipientUids': notifiedUids,
      'route': route?.name,
    },
  };

  factory CommunicationRequest.fromMap(
    Map<String, dynamic> map, {
    DeliveryStatus? delivery,
  }) {
    final notification = readMap(map['notification']);
    return CommunicationRequest(
      id: readString(map['id']) ?? '',
      childId: readString(map['childId']) ?? '',
      childName: readString(map['childName']) ?? '',
      categoryId: readString(map['categoryId']) ?? '',
      categoryTitle: readString(map['categoryTitle']) ?? '',
      message: readString(map['message']) ?? '',
      emoji: readString(map['emoji']) ?? 'necesito_hablar',
      pictogramIds: readStringList(map['pictogramIds']),
      priority: enumByName(
        RequestPriority.values,
        map['priority'],
        RequestPriority.normal,
      ),
      isUrgent: readBool(map['isUrgent'], false),
      recipientUid: readString(map['recipientUid']),
      recipientName: readString(map['recipientName']),
      createdByUid: readString(map['createdByUid']) ?? '',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      status: RequestStatus.fromKey(map['status']),
      statusUpdatedAt: parseDate(map['statusUpdatedAt']),
      statusUpdatedByUid: readString(map['statusUpdatedByUid']),
      statusUpdatedByName: readString(map['statusUpdatedByName']),
      seenAt: parseDate(map['seenAt']),
      attendingAt: parseDate(map['attendingAt']),
      resolvedAt: parseDate(map['resolvedAt']),
      note: readString(map['note']),
      delivery:
          delivery ??
          enumByName(
            DeliveryStatus.values,
            map['delivery'],
            DeliveryStatus.delivered,
          ),
      deliveredAt: parseDate(map['deliveredAt'] ?? map['serverReceivedAt']),
      notification: enumByName(
        NotificationStatus.values,
        notification['status'],
        NotificationStatus.pending,
      ),
      notifiedAt: parseDate(notification['sentAt']),
      notifiedNames: readStringList(notification['recipientNames']),
      notifiedUids: readStringList(notification['recipientUids']),
      route: notification['route'] == null
          ? null
          : enumByName(
              NotificationRoute.values,
              notification['route'],
              NotificationRoute.rule,
            ),
    );
  }
}
