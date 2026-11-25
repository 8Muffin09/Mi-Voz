'use strict';

/**
 * Base de datos de Firestore que usa Mi Voz.
 *
 * El proyecto se creó con una base con nombre (`mivoz`), no con la base
 * `(default)`. La app la abre con `FirebaseFirestore.instanceFor(databaseId:
 * 'mivoz')` (lib/app/providers.dart) y las funciones deben leer y escuchar
 * la misma: con `getFirestore()` sin nombre irían a `(default)`, no
 * encontrarían las clases ni las familias y rechazarían cada invitación.
 *
 * Debe coincidir con `firestore.database` en firebase.json.
 */
const DATABASE = 'mivoz';

module.exports = { DATABASE };
