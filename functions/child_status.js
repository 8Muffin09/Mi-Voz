'use strict';

/**
 * Aviso al niño cuando su adulto atiende lo que comunicó.
 *
 * Cuando una solicitud pasa a "vista", "en atención" (va en camino) o
 * "resuelta", se envía una notificación del sistema a los teléfonos que
 * están en modo niño para ESE perfil (`notification_tokens` con
 * `childMode: true` y `childId`). Llega aunque la app esté cerrada o en
 * segundo plano. Con la app abierta, la propia app muestra el aviso a partir
 * de los datos en tiempo real.
 */
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions/v2');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { DATABASE } = require('./database');

const RANK = { new: 0, seen: 1, attending: 2, resolved: 3 };
const INVALID_TOKEN_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

function firstName(name) {
  return String(name || '').trim().split(/\s+/)[0] || '';
}

/**
 * Qué decirle al niño (o `null` si el cambio no merece aviso). Pura: se
 * prueba sin emuladores (firebase/tests/child_status.test.mjs).
 */
function childStatusMessage(before, after) {
  if (!before || !after || after.imported === true) return null;
  const from = RANK[before.status];
  const to = RANK[after.status];
  if (from === undefined || to === undefined || to <= from) return null;
  const who = firstName(after.statusUpdatedByName);
  const message = String(after.message || '');
  switch (after.status) {
    case 'attending':
      return { title: who ? `¡${who} va en camino!` : '¡Tu adulto va en camino!', body: message };
    case 'resolved':
      return { title: '¡Listo! Ya atendieron tu mensaje', body: message };
    case 'seen':
      return { title: who ? `${who} vio tu mensaje` : 'Tu adulto vio tu mensaje', body: message };
    default:
      return null;
  }
}

exports.childStatusMessage = childStatusMessage;

exports.notifyChildOnStatusChange = onDocumentUpdated(
  { document: 'children/{childId}/communication_requests/{requestId}', database: DATABASE },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const text = childStatusMessage(before, after);
    if (!text) return;
    const { childId, requestId } = event.params;
    const db = getFirestore(DATABASE);

    const snap = await db.collection('notification_tokens').where('childId', '==', childId).get();
    const tokens = snap.docs.filter((d) => d.get('childMode') === true).map((d) => d.id);
    if (tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: text,
      data: { type: 'request_status', childId, requestId, status: String(after.status) },
      android: {
        priority: 'high',
        notification: {
          channelId: 'mi_voz_child',
          // Un solo aviso por mensaje: el nuevo estado reemplaza al anterior.
          tag: `estado-${requestId}`,
          defaultSound: true,
        },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    const cleanup = [];
    response.responses.forEach((r, i) => {
      if (!r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code)) {
        cleanup.push(db.collection('notification_tokens').doc(tokens[i]).delete());
      }
    });
    await Promise.allSettled(cleanup);
    logger.info('Aviso al niño', { childId, requestId, status: after.status, sent: response.successCount });
  },
);
