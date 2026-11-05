/**
 * Transferencia del historial guardado en un dispositivo a la cuenta.
 *
 * Las reglas de Firestore solo dejan crear solicitudes nuevas (estado "new"
 * y hora del servidor), así que el historial anterior lo escribe esta
 * función después de comprobar:
 * - que quien llama inició sesión y ADMINISTRA el perfil (ownerUid);
 * - que cada solicitud pertenece a ese perfil y tiene campos válidos;
 * - un máximo de 200 solicitudes por llamada.
 *
 * Idempotente: el identificador de la solicitud se conserva y `create()`
 * falla en silencio si ya existe, así que reintentar no duplica. Las
 * solicitudes importadas llevan `imported: true` y una notificación ya
 * cerrada, por lo que `notifyOnRequestCreated` no envía avisos por ellas.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const MAX_PER_CALL = 200;
const STATUSES = ['new', 'seen', 'attending', 'resolved'];
const PRIORITIES = ['normal', 'high'];

function str(value, max) {
  return typeof value === 'string' && value.length > 0 && value.length <= max;
}

function toTimestamp(value) {
  if (typeof value !== 'string') return null;
  const ms = Date.parse(value);
  if (Number.isNaN(ms)) return null;
  // No se aceptan fechas futuras.
  return Timestamp.fromMillis(Math.min(ms, Date.now()));
}

exports.importLocalHistory = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  const uid = request.auth.uid;
  const { childId, requests } = request.data || {};
  if (!str(childId, 128) || !Array.isArray(requests)) {
    throw new HttpsError('invalid-argument', 'Datos incompletos.');
  }
  if (requests.length > MAX_PER_CALL) {
    throw new HttpsError('invalid-argument', 'Demasiadas solicitudes en un envío.');
  }

  const db = getFirestore();
  const childRef = db.doc(`children/${childId}`);
  const child = await childRef.get();
  if (!child.exists || child.data().ownerUid !== uid) {
    throw new HttpsError('permission-denied', 'Solo quien administra el perfil puede transferir su historial.');
  }

  let imported = 0;
  let skipped = 0;
  for (const r of requests) {
    const createdAt = toTimestamp(r && r.createdAt);
    if (!r || !str(r.id, 128) || !str(r.message, 300) || !createdAt
        || !STATUSES.includes(r.status) || !PRIORITIES.includes(r.priority)) {
      skipped++;
      continue;
    }
    const doc = {
      id: r.id,
      childId,
      childName: str(r.childName, 80) ? r.childName : child.data().name,
      categoryId: str(r.categoryId, 64) ? r.categoryId : 'frase',
      categoryTitle: str(r.categoryTitle, 64) ? r.categoryTitle : '',
      message: r.message,
      // Identificador del pictograma (o emoji heredado).
      emoji: str(r.emoji, 64) ? r.emoji : 'necesito_hablar',
      pictogramIds: Array.isArray(r.pictogramIds)
        ? r.pictogramIds.filter((p) => str(p, 64)).slice(0, 20) : [],
      priority: r.priority,
      status: r.status,
      // Quien transfiere queda como emisor: la cuenta local original no
      // existe en el servidor.
      createdByUid: uid,
      createdByName: str(r.createdByName, 100) ? r.createdByName : '',
      createdAt,
      serverReceivedAt: FieldValue.serverTimestamp(),
      imported: true,
      notification: { status: 'simulated', reason: 'imported', sentAt: createdAt },
    };
    try {
      await db.doc(`children/${childId}/communication_requests/${r.id}`).create(doc);
      imported++;
    } catch (e) {
      // ALREADY_EXISTS (6): ya se había transferido.
      if (e && e.code === 6) skipped++; else throw e;
    }
  }
  return { imported, skipped };
});
