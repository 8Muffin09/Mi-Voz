'use strict';

/**
 * Limpieza al eliminar una cuenta (Firebase Authentication).
 *
 * La app ya borra lo que las reglas le permiten (perfiles que administra,
 * sus vínculos, su salida de familias ajenas y el retiro de los alumnos de
 * sus clases). Esta función completa, con permisos de servidor, lo que el
 * cliente no puede hacer y cubre cuentas borradas desde la consola:
 * - Familias que administraba: pasan al siguiente adulto o se borran.
 * - Clases que administraba: se retiran sus alumnos y se borran.
 * - Vínculos que queden con niños, tokens de notificación, solicitudes de
 *   unión, invitaciones, contador de intentos y su documento de usuario.
 */

const functionsV1 = require('firebase-functions/v1');
const { logger } = require('firebase-functions/v2');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const db = getFirestore();

/** Borra los documentos de una consulta en lotes. */
async function deleteQuery(query) {
  const snap = await query.get();
  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = db.batch();
    snap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

/** Quita al adulto de un niño (acceso, vínculo y "acompañando"). */
async function removeFromChild(childRef, uid, classId) {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(childRef);
    if (!snap.exists) return;
    const child = snap.data();
    const update = { memberUids: FieldValue.arrayRemove(uid) };
    if (classId) update.classIds = FieldValue.arrayRemove(classId);
    if (Array.isArray(child.backupUids) && child.backupUids.includes(uid)) {
      update.backupUids = FieldValue.arrayRemove(uid);
    }
    if (child.responsibleUid === uid) {
      update.responsibleUid = null;
      update.responsibleName = null;
      update.responsibleSince = null;
    }
    tx.update(childRef, update);
    tx.delete(childRef.collection('caregiver_links').doc(uid));
  });
}

exports.cleanupOnUserDeleted = functionsV1
  .region('us-central1')
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;

    // Clases: se retiran sus alumnos y se borran (o se sale si no la administra).
    const classes = await db.collection('classes').where('teacherUids', 'array-contains', uid).get();
    for (const doc of classes.docs) {
      const klass = doc.data();
      if (klass.ownerUid === uid) {
        for (const studentId of klass.studentIds || []) {
          await removeFromChild(db.doc(`children/${studentId}`), uid, doc.id);
        }
        await deleteQuery(db.collection('group_invitations').where('targetId', '==', doc.id));
        await doc.ref.delete();
      } else {
        await doc.ref.update({
          teacherUids: FieldValue.arrayRemove(uid),
          [`teacherNames.${uid}`]: FieldValue.delete(),
        });
      }
    }

    // Familias: la administra el siguiente adulto o se borra si queda vacía.
    const families = await db.collection('families').where('adultUids', 'array-contains', uid).get();
    for (const doc of families.docs) {
      const family = doc.data();
      const others = (family.adultUids || []).filter((a) => a !== uid);
      if (others.length === 0) {
        await deleteQuery(db.collection('group_invitations').where('targetId', '==', doc.id));
        await doc.ref.delete();
        continue;
      }
      await doc.ref.update({
        adultUids: FieldValue.arrayRemove(uid),
        [`adultNames.${uid}`]: FieldValue.delete(),
        [`adultRoles.${uid}`]: FieldValue.delete(),
        ...(family.ownerUid === uid ? { ownerUid: others[0] } : {}),
      });
    }

    // Niños: los que administraba se borran (cleanupOnChildDeleted borra su
    // contenido); en los demás se le quita el acceso.
    const children = await db.collection('children').where('memberUids', 'array-contains', uid).get();
    for (const doc of children.docs) {
      if (doc.get('ownerUid') === uid) {
        await doc.ref.delete();
      } else {
        await removeFromChild(doc.ref, uid, null);
      }
    }

    await deleteQuery(db.collection('notification_tokens').where('uid', '==', uid));
    await deleteQuery(db.collection('join_requests').where('requesterUid', '==', uid));
    await deleteQuery(db.collection('join_requests').where('approverUid', '==', uid));
    await deleteQuery(db.collection('group_invitations').where('ownerUid', '==', uid));
    await db.doc(`rate_limits/${uid}`).delete().catch(() => {});
    await db.doc(`users/${uid}`).delete().catch(() => {});
    logger.info('Datos de la cuenta eliminados', { uid });
  });
