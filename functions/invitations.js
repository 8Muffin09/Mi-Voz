'use strict';

/**
 * Invitaciones a familias y clases (validadas en el servidor).
 *
 * El cliente no puede escribir invitaciones, solicitudes ni membresías: lo
 * hacen estas funciones con el Admin SDK tras comprobar:
 * - que quien invita administra la familia o la clase (y tiene el correo
 *   verificado);
 * - caducidad, revocación y límite de usos del código;
 * - intentos incorrectos por cuenta (5 en 15 minutos bloquean 15 minutos);
 * - duplicados (ya es miembro, ya vinculado, solicitud pendiente);
 * - que solo un adulto de la familia del niño lo vincula con una clase.
 *
 * El QR solo contiene `mivoz://invite?code=...`: nunca datos del menor.
 * Las mismas reglas están en lib/features/invitations/data/
 * demo_invitations_repository.dart (modo "Solo en este dispositivo").
 */

const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = getFirestore();

const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;
const ALLOWED_VALIDITY_HOURS = [48, 168];
const ALLOWED_MAX_USES = [1, 5, 30];
const FAMILY_ROLES = ['madre', 'padre', 'tutor', 'cuidador'];
const MAX_FAILURES = 5;
const FAILURE_WINDOW_MS = 15 * 60 * 1000;
const LOCK_MS = 15 * 60 * 1000;

const INVITATIONS = 'group_invitations';
const REQUESTS = 'join_requests';
const RATE_LIMITS = 'rate_limits';

/** Error con un motivo que la app traduce (InvitationError). */
function fail(reason, code = 'failed-precondition') {
  throw new HttpsError(code, reason, { reason });
}

function requireAuth(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  return request.auth;
}

function normalize(code) {
  return String(code || '').trim().toUpperCase().replace(/[\s-]/g, '');
}

function wellFormed(code) {
  return code.length === CODE_LENGTH && [...code].every((c) => ALPHABET.includes(c));
}

function randomCode() {
  const bytes = crypto.randomBytes(CODE_LENGTH);
  return [...bytes].map((b) => ALPHABET[b % ALPHABET.length]).join('');
}

function statusOf(inv, now = Date.now()) {
  if (inv.revoked) return 'revoked';
  if ((inv.uses || 0) >= (inv.maxUses || 1)) return 'exhausted';
  if (inv.expiresAt.toMillis() <= now) return 'expired';
  return 'active';
}

async function displayName(uid) {
  const snap = await db.doc(`users/${uid}`).get();
  return (snap.exists && snap.get('displayName')) || 'Adulto';
}

async function userProfile(uid) {
  const snap = await db.doc(`users/${uid}`).get();
  return snap.exists ? snap.data() : {};
}

// --------------------------------------------------- intentos incorrectos

async function checkRateLimit(uid) {
  const snap = await db.doc(`${RATE_LIMITS}/${uid}`).get();
  const locked = snap.exists ? snap.get('lockedUntil') : null;
  if (locked && locked.toMillis() > Date.now()) fail('tooManyAttempts', 'resource-exhausted');
}

async function registerFailure(uid) {
  const ref = db.doc(`${RATE_LIMITS}/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const start = snap.exists && snap.get('windowStart') ? snap.get('windowStart').toMillis() : 0;
    const inWindow = now - start < FAILURE_WINDOW_MS;
    const failures = (inWindow ? snap.get('failures') || 0 : 0) + 1;
    const data = {
      failures,
      windowStart: inWindow ? Timestamp.fromMillis(start) : Timestamp.fromMillis(now),
    };
    if (failures >= MAX_FAILURES) data.lockedUntil = Timestamp.fromMillis(now + LOCK_MS);
    tx.set(ref, data);
  });
}

/** Valida el código. Los inexistentes cuentan como intento incorrecto. */
async function validate(uid, rawCode) {
  await checkRateLimit(uid);
  const code = normalize(rawCode);
  const snap = wellFormed(code) ? await db.doc(`${INVITATIONS}/${code}`).get() : null;
  if (!snap || !snap.exists) {
    await registerFailure(uid);
    fail('invalid', 'not-found');
  }
  const inv = snap.data();
  const status = statusOf(inv);
  if (status !== 'active') fail(status);
  return { code, inv };
}

// ----------------------------------------------------------------- crear

exports.createInvitation = onCall(async (request) => {
  const auth = requireAuth(request);
  if (auth.token.email_verified !== true) fail('emailNotVerified', 'permission-denied');
  const { type, targetId } = request.data || {};
  const validityHours = Number(request.data?.validityHours);
  const maxUses = Number(request.data?.maxUses);
  const requiresApproval = request.data?.requiresApproval !== false;
  if (!['family', 'classroom'].includes(type) || typeof targetId !== 'string'
      || !ALLOWED_VALIDITY_HOURS.includes(validityHours)
      || !ALLOWED_MAX_USES.includes(maxUses)) {
    fail('notAllowed', 'invalid-argument');
  }

  let targetName;
  let ownerUid;
  let role = null;
  if (type === 'family') {
    const family = await db.doc(`families/${targetId}`).get();
    if (!family.exists || family.get('ownerUid') !== auth.uid) fail('notAllowed', 'permission-denied');
    targetName = family.get('name');
    ownerUid = family.get('ownerUid');
    role = FAMILY_ROLES.includes(request.data?.role) ? request.data.role : 'tutor';
  } else {
    const klass = await db.doc(`classes/${targetId}`).get();
    if (!klass.exists || klass.get('ownerUid') !== auth.uid || klass.get('archived') === true) {
      fail('notAllowed', 'permission-denied');
    }
    targetName = klass.get('name');
    ownerUid = klass.get('ownerUid');
  }

  const now = Date.now();
  const data = {
    type,
    targetId,
    targetName,
    ownerUid,
    createdBy: auth.uid,
    createdByName: await displayName(auth.uid),
    createdAt: Timestamp.fromMillis(now),
    expiresAt: Timestamp.fromMillis(now + validityHours * 3600 * 1000),
    maxUses,
    uses: 0,
    revoked: false,
    requiresApproval,
    role,
  };
  // Código único (create falla si ya existe: se reintenta con otro).
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomCode();
    try {
      await db.doc(`${INVITATIONS}/${code}`).create({ ...data, code });
      return {
        ...data,
        code,
        createdAt: data.createdAt.toDate().toISOString(),
        expiresAt: data.expiresAt.toDate().toISOString(),
      };
    } catch (e) {
      if (e.code !== 6 /* ALREADY_EXISTS */) throw e;
    }
  }
  throw new HttpsError('internal', 'No se pudo generar un código.');
});

exports.revokeInvitation = onCall(async (request) => {
  const auth = requireAuth(request);
  const code = normalize(request.data?.code);
  const ref = db.doc(`${INVITATIONS}/${code}`);
  const snap = await ref.get();
  if (!snap.exists) fail('invalid', 'not-found');
  if (snap.get('createdBy') !== auth.uid && snap.get('ownerUid') !== auth.uid) {
    fail('notAllowed', 'permission-denied');
  }
  await ref.update({ revoked: true });
  return { ok: true };
});

// ----------------------------------------------------------- vista previa

exports.previewInvitation = onCall(async (request) => {
  const auth = requireAuth(request);
  const { code, inv } = await validate(auth.uid, request.data?.code);
  return {
    code,
    type: inv.type,
    targetName: inv.targetName,
    inviterName: inv.createdByName,
    requiresApproval: inv.requiresApproval !== false,
    role: inv.role || null,
  };
});

// --------------------------------------------- registrar la incorporación

/** Agrega al adulto a la familia y a todos sus niños (dentro de `tx`). */
async function joinFamily(tx, familyRef, family, uid, name, email, role) {
  if ((family.adultUids || []).includes(uid)) return;
  const kids = await tx.get(db.collection('children').where('familyId', '==', familyRef.id));
  tx.update(familyRef, {
    adultUids: FieldValue.arrayUnion(uid),
    [`adultNames.${uid}`]: name,
    [`adultRoles.${uid}`]: role,
  });
  for (const kid of kids.docs) {
    tx.update(kid.ref, { memberUids: FieldValue.arrayUnion(uid) });
    tx.set(kid.ref.collection('caregiver_links').doc(uid), {
      childId: kid.id,
      adultUid: uid,
      adultName: name,
      adultEmail: email || '',
      role,
      permission: 'caregiver',
      source: 'family',
      classIds: [],
      receivesRequests: true,
      canViewPassport: true,
      invitedByUid: family.ownerUid,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

/** Vincula al niño con la clase y da acceso a sus docentes (dentro de `tx`). */
async function linkChildToClass(tx, classRef, klass, childRef, child) {
  const teacherLinks = await Promise.all(
    (klass.teacherUids || []).map((t) => tx.get(childRef.collection('caregiver_links').doc(t))),
  );
  tx.update(classRef, { studentIds: FieldValue.arrayUnion(childRef.id) });
  const childUpdate = { classIds: FieldValue.arrayUnion(classRef.id) };
  const newTeachers = [];
  teacherLinks.forEach((link, i) => {
    const teacher = klass.teacherUids[i];
    if (link.exists) {
      tx.update(link.ref, { classIds: FieldValue.arrayUnion(classRef.id) });
      return;
    }
    newTeachers.push(teacher);
    tx.set(link.ref, {
      childId: childRef.id,
      adultUid: teacher,
      adultName: (klass.teacherNames || {})[teacher] || 'Docente',
      adultEmail: '',
      role: 'docente',
      permission: 'caregiver',
      source: 'classroom',
      classIds: [classRef.id],
      receivesRequests: true,
      canViewPassport: true,
      invitedByUid: child.ownerUid,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  if (newTeachers.length) childUpdate.memberUids = FieldValue.arrayUnion(...newTeachers);
  tx.update(childRef, childUpdate);
}

async function canLinkChild(child, uid) {
  if (child.familyId) {
    const family = await db.doc(`families/${child.familyId}`).get();
    return family.exists && (family.get('adultUids') || []).includes(uid);
  }
  return child.ownerUid === uid;
}

exports.redeemInvitation = onCall(async (request) => {
  const auth = requireAuth(request);
  const { code, inv } = await validate(auth.uid, request.data?.code);
  const childId = typeof request.data?.childId === 'string' ? request.data.childId : null;
  const profile = await userProfile(auth.uid);
  const name = profile.displayName || 'Adulto';

  let approverUid;
  let child = null;
  if (inv.type === 'family') {
    const family = await db.doc(`families/${inv.targetId}`).get();
    if (!family.exists) fail('invalid', 'not-found');
    if ((family.get('adultUids') || []).includes(auth.uid)) fail('alreadyMember');
    approverUid = family.get('ownerUid');
  } else {
    const klass = await db.doc(`classes/${inv.targetId}`).get();
    if (!klass.exists || klass.get('archived') === true) fail('invalid', 'not-found');
    if (!childId) fail('childRequired', 'invalid-argument');
    const childSnap = await db.doc(`children/${childId}`).get();
    if (!childSnap.exists || !(await canLinkChild(childSnap.data(), auth.uid))) {
      fail('childNotAllowed', 'permission-denied');
    }
    child = childSnap.data();
    if ((child.classIds || []).includes(inv.targetId)) fail('alreadyLinked');
    approverUid = klass.get('ownerUid');
  }

  // Duplicados: una sola solicitud pendiente por persona (y niño) y grupo.
  let pending = db.collection(REQUESTS)
    .where('requesterUid', '==', auth.uid)
    .where('targetId', '==', inv.targetId)
    .where('status', '==', 'pending');
  if (childId) pending = pending.where('childId', '==', childId);
  if (!(await pending.limit(1).get()).empty) fail('alreadyRequested');

  const invRef = db.doc(`${INVITATIONS}/${code}`);
  const outcome = await db.runTransaction(async (tx) => {
    // Se vuelve a leer dentro de la transacción: usos concurrentes.
    const fresh = await tx.get(invRef);
    const status = statusOf(fresh.data());
    if (status !== 'active') fail(status);
    if (inv.requiresApproval !== false) {
      tx.update(invRef, { uses: FieldValue.increment(1) });
      tx.set(db.collection(REQUESTS).doc(), {
        code,
        type: inv.type,
        targetId: inv.targetId,
        targetName: inv.targetName,
        requesterUid: auth.uid,
        requesterName: name,
        approverUid,
        childId,
        childName: child ? child.name : null,
        role: inv.role || null,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
      });
      return 'pendingApproval';
    }
    if (inv.type === 'family') {
      const familyRef = db.doc(`families/${inv.targetId}`);
      const family = (await tx.get(familyRef)).data();
      await joinFamily(tx, familyRef, family, auth.uid, name, profile.email, inv.role || 'tutor');
    } else {
      const classRef = db.doc(`classes/${inv.targetId}`);
      const childRef = db.doc(`children/${childId}`);
      const klass = (await tx.get(classRef)).data();
      const freshChild = (await tx.get(childRef)).data();
      await linkChildToClass(tx, classRef, klass, childRef, freshChild);
    }
    tx.update(invRef, { uses: FieldValue.increment(1) });
    return 'joined';
  });
  return { outcome };
});

// ---------------------------------------------------------------- aprobar

exports.reviewJoinRequest = onCall(async (request) => {
  const auth = requireAuth(request);
  const requestId = request.data?.requestId;
  const approve = request.data?.approve === true;
  if (typeof requestId !== 'string') fail('notAllowed', 'invalid-argument');
  const reqRef = db.doc(`${REQUESTS}/${requestId}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(reqRef);
    if (!snap.exists) fail('notAllowed', 'not-found');
    const jr = snap.data();
    if (jr.approverUid !== auth.uid || jr.status !== 'pending') fail('notAllowed', 'permission-denied');

    if (approve) {
      const requester = await tx.get(db.doc(`users/${jr.requesterUid}`));
      const name = (requester.exists && requester.get('displayName')) || jr.requesterName;
      const email = requester.exists ? requester.get('email') : '';
      if (jr.type === 'family') {
        const familyRef = db.doc(`families/${jr.targetId}`);
        const family = await tx.get(familyRef);
        if (!family.exists) fail('notAllowed', 'not-found');
        await joinFamily(tx, familyRef, family.data(), jr.requesterUid, name, email, jr.role || 'tutor');
      } else {
        const classRef = db.doc(`classes/${jr.targetId}`);
        const childRef = db.doc(`children/${jr.childId}`);
        const klass = await tx.get(classRef);
        const child = await tx.get(childRef);
        // Se vuelve a comprobar: pudo cambiar desde la solicitud.
        if (!klass.exists || klass.get('archived') === true || !child.exists) {
          fail('notAllowed', 'failed-precondition');
        }
        if (child.get('familyId')) {
          const family = await tx.get(db.doc(`families/${child.get('familyId')}`));
          if (!family.exists || !(family.get('adultUids') || []).includes(jr.requesterUid)) {
            fail('notAllowed', 'permission-denied');
          }
        } else if (child.get('ownerUid') !== jr.requesterUid) {
          fail('notAllowed', 'permission-denied');
        }
        await linkChildToClass(tx, classRef, klass.data(), childRef, child.data());
      }
    }
    tx.update(reqRef, {
      status: approve ? 'approved' : 'rejected',
      reviewedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});
