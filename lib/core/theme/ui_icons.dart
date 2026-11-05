import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/communication_request.dart';
import '../../models/sensory_passport.dart';
import '../../models/support_strategy.dart';

/// Iconos de interfaz (navegación, estados y administración). Son de la
/// familia Material Symbols "rounded" en toda la app; los pictogramas
/// ilustrados se reservan para la comunicación y los avatares para la
/// identidad de cada perfil.
extension AdultRoleIcon on AdultRole {
  IconData get icon => switch (this) {
    AdultRole.madre ||
    AdultRole.padre ||
    AdultRole.tutor => Icons.family_restroom_rounded,
    AdultRole.docente => Icons.school_rounded,
    AdultRole.cuidador => Icons.volunteer_activism_rounded,
  };
}

extension RequestStatusIcon on RequestStatus {
  IconData get icon => switch (this) {
    RequestStatus.newRequest => Icons.fiber_new_rounded,
    RequestStatus.seen => Icons.visibility_rounded,
    RequestStatus.attending => Icons.directions_walk_rounded,
    RequestStatus.resolved => Icons.check_circle_rounded,
  };
}

extension StrategyPlaceIcon on StrategyPlace {
  IconData get icon => switch (this) {
    StrategyPlace.home => Icons.home_rounded,
    StrategyPlace.school => Icons.school_rounded,
    StrategyPlace.therapy => Icons.healing_rounded,
    StrategyPlace.community => Icons.park_rounded,
    StrategyPlace.other => Icons.place_rounded,
  };
}

extension StrategyResultIcon on StrategyResult {
  IconData get icon => switch (this) {
    StrategyResult.worked => Icons.check_circle_rounded,
    StrategyResult.partial => Icons.adjust_rounded,
    StrategyResult.notWorked => Icons.cancel_rounded,
    StrategyResult.toTry => Icons.science_rounded,
  };

  Color get color => switch (this) {
    StrategyResult.worked => const Color(0xFF2E7D4F),
    StrategyResult.partial => const Color(0xFFB07A00),
    StrategyResult.notWorked => const Color(0xFFB3261E),
    StrategyResult.toTry => const Color(0xFF3F5F9E),
  };
}

/// Áreas sensoriales: son conceptos de comunicación, así que usan el mismo
/// pictograma que "Me molesta ..." en el modo infantil.
extension SensoryAreaSymbol on SensoryArea {
  String get symbol => switch (this) {
    SensoryArea.noise => 'me_molesta_ruido',
    SensoryArea.light => 'me_molesta_luz',
    SensoryArea.touch => 'me_molesta_contacto',
    SensoryArea.smell => 'me_molesta_olor',
    SensoryArea.texture => 'me_molesta_textura',
  };
}
