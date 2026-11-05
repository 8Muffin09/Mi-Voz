'use strict';

/**
 * Backend de Mi Voz (Cloud Functions de Firebase, 2.ª generación).
 *
 * - notifyOnRequestCreated: cuando un niño comunica algo, verifica que el
 *   emisor esté autorizado, resuelve el destinatario (quien acompaña o, si
 *   nadie acompaña, la regla que eligió el administrador del perfil) y envía
 *   la notificación push con credenciales de servidor. Escribe el resultado
 *   en `notification`.
 * - notifyOnJoinRequest: avisa a quien debe aprobar una solicitud de unión.
 * - cleanupOnUserDeleted: al borrar una cuenta, entrega o borra sus familias,
 *   cierra sus clases y elimina sus vínculos y datos (ver account.js).
 * - cleanupOnChildDeleted: al eliminar un perfil, borra sus subcolecciones,
 *   sus invitaciones y sus fotos en Storage.
 * - importLocalHistory: transfiere el historial de un dispositivo al perfil
 *   en la nube (solo el administrador; ver migration.js).
 * - createInvitation, previewInvitation, redeemInvitation, revokeInvitation,
 *   reviewJoinRequest: invitaciones a familias y clases (ver invitations.js).
 *
 * El cliente móvil nunca tiene credenciales privadas: solo guarda su token.
 */

const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getStorage } = require('firebase-admin/storage');

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

// Invitaciones a familias y clases, validadas en el servidor.
Object.assign(exports, require('./invitations'));
// Limpieza al eliminar una cuenta.
Object.assign(exports, require('./account'));
Object.assign(exports, require('./migration'));

const db = getFirestore();

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Divide un arreglo en bloques (las consultas `in` aceptan hasta 30 valores). */
function chunk(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

/** Tokens de dispositivos de adultos (excluye dispositivos en modo niño). */
async function tokensFor(uids) {
  const tokens = [];
  for (const part of chunk(uids, 30)) {
    const snap = await db.collection('notification_tokens').where('uid', 'in', part).get();
    for (const doc of snap.docs) {
      if (doc.data().childMode !== true) tokens.push(doc.id);
    }
  }
  return tokens;
}

async function namesFor(childId, uids) {
  const names = [];
  for (const uid of uids) {
    const link = await db.doc(`children/${childId}/caregiver_links/${uid}`).get();
    if (link.exists) names.push(link.get('adultName'));
  }
  return names;
}

exports.notifyOnRequestCreated = onDocumentCreated(
  'children/{childId}/communication_requests/{requestId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const request = snap.data();
    const { childId, requestId } = event.params;

    // Idempotencia: los eventos pueden entregarse más de una vez. Las
    // solicitudes transferidas del historial (migration.js) no avisan.
    if (request.imported === true) return;
    if (request.notification && request.notification.status !== 'pending') return;

    const childSnap = await db.doc(`children/${childId}`).get();
    if (!childSnap.exists) {
      await snap.ref.update({
        notification: { status: 'failed', reason: 'child_not_found', sentAt: FieldValue.serverTimestamp() },
      });
      return;
    }
    const child = childSnap.data();
    const members = Array.isArray(child.memberUids) ? child.memberUids : [];

    // Solo adultos vinculados pueden generar solicitudes.
    if (!members.includes(request.createdByUid)) {
      logger.warn('Solicitud de un usuario no vinculado', { childId, requestId });
      await snap.ref.update({
        notification: { status: 'failed', reason: 'unauthorized', sentAt: FieldValue.serverTimestamp() },
      });
      return;
    }

    // La familia puede impedir que un adulto reciba solicitudes.
    const links = await db.collection(`children/${childId}/caregiver_links`).get();
    const blocked = new Set(
      links.docs.filter((d) => d.data().receivesRequests === false).map((d) => d.id),
    );
    const allowed = (uid) => members.includes(uid) && !blocked.has(uid);

    // Misma lógica que RecipientResolver.plan (lib/core/permissions):
    // 1) quien acompaña ahora; 2) si nadie acompaña, o quien acompaña no tiene
    // dispositivos, la regla que eligió el administrador. Nunca se avisa a
    // todos los adultos si el administrador no lo eligió.
    const companion = child.responsibleUid && allowed(child.responsibleUid)
      ? child.responsibleUid
      : null;
    const rule = ['admin', 'chosen', 'all'].includes(child.noCompanionRule)
      ? child.noCompanionRule
      : 'admin';
    const ruleCandidates = rule === 'all'
      ? members
      : rule === 'chosen'
        ? (Array.isArray(child.backupUids) ? child.backupUids : [])
        : [child.ownerUid];
    const byRule = [...new Set(ruleCandidates.filter(allowed))];

    let recipients = companion ? [companion] : byRule;
    let route = companion ? 'companion' : 'rule';
    let tokens = await tokensFor(recipients);

    if (tokens.length === 0 && companion) {
      const fallback = byRule.filter((uid) => uid !== companion);
      if (fallback.length > 0) {
        recipients = fallback;
        route = 'ruleAfterCompanion';
        tokens = await tokensFor(recipients);
      }
    }

    if (recipients.length === 0) {
      await snap.ref.update({
        notification: {
          status: 'noRecipients',
          recipientUids: [],
          recipientNames: [],
          route,
          sentAt: FieldValue.serverTimestamp(),
        },
      });
      return;
    }

    const recipientNames = await namesFor(childId, recipients);
    const urgent = request.isUrgent === true || request.priority === 'high';
    const title = urgent
      ? `🆘 ${child.name} necesita ayuda urgente`
      : `${child.name} necesita atención`;

    if (tokens.length === 0) {
      await snap.ref.update({
        notification: {
          status: 'noDevices',
          recipientUids: recipients,
          recipientNames,
          route,
          sentAt: FieldValue.serverTimestamp(),
        },
      });
      return;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body: String(request.message || '') },
      data: {
        type: 'communication_request',
        childId,
        requestId,
        urgent: String(urgent),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: urgent ? 'mi_voz_urgent' : 'mi_voz_requests',
          tag: requestId,
          defaultSound: true,
        },
      },
      apns: {
        headers: { 'apns-priority': urgent ? '10' : '5' },
        payload: { aps: { sound: 'default' } },
      },
    });

    // Limpieza de tokens inválidos.
    const cleanup = [];
    response.responses.forEach((r, i) => {
      if (!r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code)) {
        cleanup.push(db.collection('notification_tokens').doc(tokens[i]).delete());
      }
    });
    await Promise.allSettled(cleanup);

    await snap.ref.update({
      notification: {
        status: response.successCount > 0 ? 'sent' : 'failed',
        successCount: response.successCount,
        failureCount: response.failureCount,
        recipientUids: recipients,
        recipientNames,
        route,
        sentAt: FieldValue.serverTimestamp(),
      },
    });
  },
);

// Aviso a quien debe aprobar una solicitud para unirse a una familia o
// vincular a un niño con una clase (la crea redeemInvitation).
exports.notifyOnJoinRequest = onDocumentCreated('join_requests/{requestId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const request = snap.data();
  if (request.status !== 'pending' || !request.approverUid) return;
  const tokens = await tokensFor([request.approverUid]);
  if (tokens.length === 0) return;
  const what = request.type === 'classroom'
    ? `vincular a ${request.childName || 'un niño'} con ${request.targetName}`
    : `unirse a ${request.targetName}`;
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: 'Solicitud por aprobar',
      body: `${request.requesterName || 'Un adulto'} quiere ${what}.`,
    },
    data: { type: 'join_request', requestId: event.params.requestId },
    android: {
      priority: 'normal',
      notification: { channelId: 'mi_voz_requests', tag: event.params.requestId },
    },
  });
  const cleanup = [];
  response.responses.forEach((r, i) => {
    if (!r.success && r.error && INVALID_TOKEN_CODES.has(r.error.code)) {
      cleanup.push(db.collection('notification_tokens').doc(tokens[i]).delete());
    }
  });
  await Promise.allSettled(cleanup);
});

exports.cleanupOnChildDeleted = onDocumentDeleted('children/{childId}', async (event) => {
  const { childId } = event.params;
  const childRef = db.doc(`children/${childId}`);
  await db.recursiveDelete(childRef);

  const invitations = await db.collection('invitations').where('childId', '==', childId).get();
  await Promise.allSettled(invitations.docs.map((d) => d.ref.delete()));

  // Sale de las clases en las que estaba (la familia no puede editarlas).
  const classes = await db.collection('classes').where('studentIds', 'array-contains', childId).get();
  await Promise.allSettled(
    classes.docs.map((d) => d.ref.update({ studentIds: FieldValue.arrayRemove(childId) })),
  );

  try {
    await getStorage().bucket().deleteFiles({ prefix: `children/${childId}/` });
  } catch (e) {
    logger.warn('No se pudieron borrar archivos de Storage', { childId, error: String(e) });
  }
});
