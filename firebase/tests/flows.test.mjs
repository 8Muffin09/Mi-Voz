// Recorridos entre dispositivos independientes contra los emuladores de
// Firebase (Auth y Firestore con las reglas reales). Las invitaciones no usan
// Cloud Functions (plan Spark): son transacciones del cliente que las reglas
// validan, igual que en la app. No sustituye la prueba en dos teléfonos.
//
//   cd firebase/tests && npm install && cd ../..
//   firebase emulators:exec --project demo-mivoz --only auth,firestore \
//     "node --test --test-concurrency=1 firebase/tests/flows.test.mjs"
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  collection, getDocs, onSnapshot, updateDoc, deleteDoc, arrayUnion, runTransaction,
  increment,
} from 'firebase/firestore';
import {
  newDevice, uniqueEmail, register, registerVerified, oobCodes,
  clickVerificationLink, refreshVerification, signInWithEmailAndPassword,
  sendPasswordResetEmail, signOut, doc, getDoc, setDoc, writeBatch,
  serverTimestamp, createFamily, createClass, createChild, requestData,
  rejects, firestoreAdminPatch,
} from './helpers.mjs';
import {
  createInvitation, preview, redeem, review, pendingFor, requestIdFor,
} from './invitations.mjs';

const devices = [];
function device(label) {
  const d = newDevice(label);
  devices.push(d);
  return d;
}
test.after(async () => {
  await Promise.all(devices.map((d) => d.close()));
});

/** Docente verificada con una clase, en su propio teléfono. */
async function teacherWithClass() {
  const phone = device('docente');
  const email = uniqueEmail('docente');
  const user = await registerVerified(phone, { email, name: 'Ana', role: 'docente' });
  const classId = await createClass(phone, user, '1.º A', 'Ana');
  return { phone, user, email, classId };
}

/** Tutor verificado con un perfil infantil, en otro teléfono. */
async function guardianWithChild() {
  const phone = device('familia');
  const email = uniqueEmail('familia');
  const user = await registerVerified(phone, { email, name: 'Rosa', role: 'madre' });
  const childId = await createChild(phone, user, 'Leo', 'Rosa');
  return { phone, user, email, childId };
}

/** La familia vincula a su niño con la clase y la docente aprueba. */
async function linkChildToClass(t, g) {
  const code = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId, maxUses: 5 });
  await redeem(g.phone, code, g.childId);
  const req = (await pendingFor(t.phone)).find((d) => d.get('childId') === g.childId);
  await review(t.phone, req, true);
}

async function reasonOf(promise) {
  const e = await rejects(promise);
  return e.reason ?? e.code;
}

test('1. Registro de adulto: cuenta y perfil asociado al uid, sin contraseña', async () => {
  const phone = device('registro');
  const email = uniqueEmail('registro');
  const user = await register(phone, { email, name: 'María', role: 'madre' });
  const profile = await getDoc(doc(phone.db, `users/${user.uid}`));
  assert.equal(profile.exists(), true);
  assert.equal(profile.get('displayName'), 'María');
  assert.equal(profile.get('role'), 'madre');
  for (const key of Object.keys(profile.data())) {
    assert.doesNotMatch(key, /pass|clave|contrase/i);
  }
  const other = device('otro');
  await register(other, { email: uniqueEmail('otro'), name: 'Otro', role: 'tutor' });
  await rejects(setDoc(doc(other.db, `users/${user.uid}`), {
    uid: user.uid, email, displayName: 'Suplantación', role: 'docente',
  }));
});

test('1b. Reintentar el registro no duplica la cuenta ni el perfil', async () => {
  const phone = device('reintento');
  const email = uniqueEmail('reintento');
  const user = await register(phone, { email, name: 'Luis', role: 'padre' });
  const second = await rejects(register(device('reintento2'), { email, name: 'Luis', role: 'padre' }));
  assert.equal(second.code, 'auth/email-already-in-use');
  const again = device('reintento3');
  const cred = await signInWithEmailAndPassword(again.auth, email, 'clave1234');
  assert.equal(cred.user.uid, user.uid);
});

test('2. Verificación de correo: se envía, "Ya confirmé" no basta y el servidor la exige', async () => {
  const phone = device('verificar');
  const email = uniqueEmail('verificar');
  const user = await register(phone, { email, name: 'Eva', role: 'docente' });
  const sent = (await oobCodes(email)).filter((c) => c.requestType === 'VERIFY_EMAIL');
  assert.equal(sent.length, 1, 'se envió un correo de verificación');

  assert.equal(await refreshVerification(phone), false);
  await rejects(setDoc(doc(phone.db, 'classes/sin-verificar'), {
    id: 'sin-verificar', name: 'X', description: '', ownerUid: user.uid,
    teacherUids: [user.uid], studentIds: [], archived: false,
  }));
  // Sin verificar tampoco puede consultar códigos.
  await rejects(getDoc(doc(phone.db, 'group_invitations/ABCDEFGH')));

  await clickVerificationLink(email);
  assert.equal(await refreshVerification(phone), true);
  await createClass(phone, user, 'Clase verificada', 'Eva');
});

test('3 y 12. Otro dispositivo (o la app reabierta) recupera perfil y datos autorizados', async () => {
  const g = await guardianWithChild();
  await g.phone.close();
  const newPhone = device('familia-nuevo');
  const cred = await signInWithEmailAndPassword(newPhone.auth, g.email, 'clave1234');
  assert.equal(cred.user.emailVerified, true);
  const profile = await getDoc(doc(newPhone.db, `users/${cred.user.uid}`));
  assert.equal(profile.get('displayName'), 'Rosa');
  const child = await getDoc(doc(newPhone.db, `children/${g.childId}`));
  assert.equal(child.get('name'), 'Leo');
});

test('4. Recuperación de contraseña por correo', async () => {
  const phone = device('olvido');
  const email = uniqueEmail('olvido');
  await register(phone, { email, name: 'Paco', role: 'tutor' });
  await signOut(phone.auth);
  await sendPasswordResetEmail(phone.auth, email);
  const reset = (await oobCodes(email)).filter((c) => c.requestType === 'PASSWORD_RESET');
  assert.equal(reset.length, 1);
});

test('5 y 6. Invitación de familia: creada en un teléfono, canjeada en otro y aprobada', async () => {
  const owner = device('familia-a');
  const ownerUser = await registerVerified(owner, { email: uniqueEmail('familia-a'), name: 'Rosa', role: 'madre' });
  const familyId = await createFamily(owner, ownerUser, 'Familia López', 'Rosa');
  const childId = await createFamilyChild(owner, ownerUser, familyId);
  const code = await createInvitation(owner, { type: 'family', targetId: familyId, maxUses: 5, role: 'padre' });
  assert.match(code, /^[A-HJKMNP-Z2-9]{8}$/);
  // Confirmada en el servidor antes de compartirse.
  const stored = await getDoc(doc(owner.db, `group_invitations/${code}`));
  assert.equal(stored.get('uses'), 0);

  const other = device('familia-b');
  const otherUser = await registerVerified(other, { email: uniqueEmail('familia-b'), name: 'Juan', role: 'padre' });
  // Escrito con minúsculas, espacios y guion (o leído del QR): mismo código.
  const typed = `${code.slice(0, 4).toLowerCase()} - ${code.slice(4)}`;
  const shown = await preview(other, typed);
  assert.equal(shown.targetName, 'Familia López');
  await redeem(other, code);

  // Pendiente: todavía no entra.
  await rejects(getDoc(doc(other.db, `families/${familyId}`)));
  await rejects(getDoc(doc(other.db, `children/${childId}`)));
  // Otro toque no duplica la solicitud.
  assert.equal(await reasonOf(redeem(other, code)), 'alreadyRequested');

  const [req] = await pendingFor(owner);
  await review(owner, req, true);
  const family = await getDoc(doc(other.db, `families/${familyId}`));
  assert.ok(family.get('adultUids').includes(otherUser.uid));
  const child = await getDoc(doc(other.db, `children/${childId}`));
  assert.ok(child.get('memberUids').includes(otherUser.uid));
  const link = await getDoc(doc(other.db, `children/${childId}/caregiver_links/${otherUser.uid}`));
  assert.equal(link.get('permission'), 'caregiver');
});

/** Perfil infantil dentro de una familia (como la app). */
async function createFamilyChild(device_, user, familyId) {
  const id = `nino-fam-${Date.now()}`;
  const batch = writeBatch(device_.db);
  batch.set(doc(device_.db, `children/${id}`), {
    id, name: 'Sofi', avatar: 'animal_cat', avatarColor: 0, gender: 'feminine',
    ownerUid: user.uid, memberUids: [user.uid], familyId, classIds: [],
    noCompanionRule: 'admin', backupUids: [], settings: {}, createdAt: serverTimestamp(),
  });
  batch.set(doc(device_.db, `children/${id}/caregiver_links/${user.uid}`), {
    childId: id, adultUid: user.uid, adultName: 'Rosa', adultEmail: '', role: 'madre',
    permission: 'owner', source: 'family', classIds: [], receivesRequests: true,
    canViewPassport: true, createdAt: serverTimestamp(),
  });
  await batch.commit();
  return id;
}

test('7. Código incorrecto, vencido, revocado o sin usos', async () => {
  const t = await teacherWithClass();
  const g = await guardianWithChild();

  assert.equal(await reasonOf(preview(g.phone, 'ZZZZZZZZ')), 'invalid');

  const revoked = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId });
  await updateDoc(doc(t.phone.db, `group_invitations/${revoked}`), { revoked: true });
  assert.equal(await reasonOf(preview(g.phone, revoked)), 'revoked');

  const expired = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId });
  await firestoreAdminPatch(`group_invitations/${expired}`, {
    createdAt: { timestampValue: '2020-01-01T00:00:00Z' },
  });
  assert.equal(await reasonOf(preview(g.phone, expired)), 'expired');
  // Aunque la app no lo detectara, el servidor rechaza canjear una vencida.
  await rejects(forceRedeem(g, expired, t.classId));

  const single = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId, maxUses: 1 });
  await redeem(g.phone, single, g.childId);
  const g2 = await guardianWithChild();
  assert.equal(await reasonOf(redeem(g2.phone, single, g2.childId)), 'exhausted');
  await rejects(forceRedeem(g2, single, t.classId));
});

/** Canje "a mano" saltándose las comprobaciones de la app. */
function forceRedeem(g, code, classId) {
  const rid = requestIdFor(g.user.uid, classId, g.childId);
  return runTransaction(g.phone.db, async (tx) => {
    const ref = doc(g.phone.db, `group_invitations/${code}`);
    const inv = await tx.get(ref);
    tx.update(ref, { uses: inv.get('uses') + 1, lastRequestId: rid });
    tx.set(doc(g.phone.db, `join_requests/${rid}`), {
      id: rid, code, type: 'classroom', targetId: classId, targetName: inv.get('targetName'),
      requesterUid: g.user.uid, requesterName: 'Rosa', approverUid: inv.get('ownerUid'),
      childId: g.childId, childName: 'Leo', role: null, status: 'pending',
      createdAt: serverTimestamp(), reviewedAt: null,
    });
  });
}

test('7b. No se pueden listar ni fabricar invitaciones ni gastar usos sin solicitud', async () => {
  const t = await teacherWithClass();
  const g = await guardianWithChild();
  const code = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId, maxUses: 5 });
  // Listar todas las invitaciones para buscar códigos: rechazado.
  await rejects(getDocs(collection(g.phone.db, 'group_invitations')));
  // Gastar usos sin crear la solicitud: rechazado.
  await rejects(updateDoc(doc(g.phone.db, `group_invitations/${code}`), { uses: increment(1) }));
  // Inventar una invitación para la clase de otra persona: rechazado.
  await rejects(setDoc(doc(g.phone.db, 'group_invitations/QQQQQQQQ'), {
    code: 'QQQQQQQQ', type: 'classroom', targetId: t.classId, targetName: '1.º A',
    ownerUid: g.user.uid, createdBy: g.user.uid, createdByName: 'Rosa',
    createdAt: serverTimestamp(), validityHours: 48, maxUses: 30, uses: 0,
    revoked: false, requiresApproval: true, role: null, lastRequestId: null,
  }));
  // Solicitud ya aprobada desde el cliente: rechazado.
  const rid = requestIdFor(g.user.uid, t.classId, g.childId);
  await rejects(runTransaction(g.phone.db, async (tx) => {
    const ref = doc(g.phone.db, `group_invitations/${code}`);
    const inv = await tx.get(ref);
    tx.update(ref, { uses: inv.get('uses') + 1, lastRequestId: rid });
    tx.set(doc(g.phone.db, `join_requests/${rid}`), {
      id: rid, code, type: 'classroom', targetId: t.classId, targetName: '1.º A',
      requesterUid: g.user.uid, requesterName: 'Rosa', approverUid: t.user.uid,
      childId: g.childId, childName: 'Leo', role: null, status: 'approved',
      createdAt: serverTimestamp(), reviewedAt: null,
    });
  }));
  const stored = await getDoc(doc(t.phone.db, `group_invitations/${code}`));
  assert.equal(stored.get('uses'), 0);
});

test('7c. Dos canjes simultáneos del último uso: solo uno entra', async () => {
  const t = await teacherWithClass();
  const code = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId, maxUses: 1 });
  const a = await guardianWithChild();
  const b = await guardianWithChild();
  const results = await Promise.allSettled([
    redeem(a.phone, code, a.childId),
    redeem(b.phone, code, b.childId),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const stored = await getDoc(doc(t.phone.db, `group_invitations/${code}`));
  assert.equal(stored.get('uses'), 1);
  assert.equal((await pendingFor(t.phone)).length, 1);
});

test('8. Aprobación pendiente sin acceso anticipado; nadie se aprueba a sí mismo', async () => {
  const t = await teacherWithClass();
  const g = await guardianWithChild();
  const code = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId, maxUses: 5 });
  const taps = await Promise.allSettled([
    redeem(g.phone, code, g.childId),
    redeem(g.phone, code, g.childId),
  ]);
  assert.equal(taps.filter((r) => r.status === 'fulfilled').length, 1);
  const requests = (await pendingFor(t.phone)).filter((d) => d.get('childId') === g.childId);
  assert.equal(requests.length, 1);
  await rejects(getDoc(doc(t.phone.db, `children/${g.childId}`)));
  // Quien solicita no puede aprobarse ni agregarse al perfil por su cuenta.
  await rejects(updateDoc(doc(g.phone.db, `join_requests/${requests[0].id}`), {
    status: 'approved', reviewedAt: serverTimestamp(),
  }));
  // La docente no puede agregarse al perfil sin aprobar la solicitud.
  await rejects(updateDoc(doc(t.phone.db, `children/${g.childId}`), {
    memberUids: arrayUnion(t.user.uid), classIds: arrayUnion(t.classId),
    lastClassChange: t.classId, lastJoinRequest: requests[0].id,
  }));
  await review(t.phone, requests[0], true);
  const child = await getDoc(doc(t.phone.db, `children/${g.childId}`));
  assert.ok(child.get('classIds').includes(t.classId));
  const klass = await getDoc(doc(t.phone.db, `classes/${t.classId}`));
  assert.ok(klass.get('studentIds').includes(g.childId));
  // La familia ve que fue aprobada.
  const mine = await getDoc(doc(g.phone.db, `join_requests/${requests[0].id}`));
  assert.equal(mine.get('status'), 'approved');
});

test('8b. Rechazar no da acceso; se puede volver a pedir con otro uso', async () => {
  const t = await teacherWithClass();
  const g = await guardianWithChild();
  const code = await createInvitation(t.phone, { type: 'classroom', targetId: t.classId, maxUses: 5 });
  await redeem(g.phone, code, g.childId);
  const [req] = await pendingFor(t.phone);
  await review(t.phone, req, false);
  await rejects(getDoc(doc(t.phone.db, `children/${g.childId}`)));
  await redeem(g.phone, code, g.childId);
  assert.equal((await pendingFor(t.phone)).length, 1);
});

test('9, 10, 11 y 16. Solicitud del alumno: llega, se atiende, se valora y no se duplica', async () => {
  const t = await teacherWithClass();
  const g = await guardianWithChild();
  await linkChildToClass(t, g);

  const seen = [];
  const unsubscribe = onSnapshot(
    collection(t.phone.db, `children/${g.childId}/communication_requests`),
    (q) => q.docChanges().forEach((c) => seen.push([c.type, c.doc.get('status')])),
  );

  const id = `req-${Date.now()}`;
  const ref = doc(g.phone.db, `children/${g.childId}/communication_requests/${id}`);
  const deliver = () => runTransaction(g.phone.db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) tx.set(ref, requestData(g.childId, g.user.uid, id));
  });
  await deliver();
  await deliver();
  await rejects(setDoc(ref, requestData(g.childId, g.user.uid, id, 'Otro texto')));
  const all = await getDocs(collection(t.phone.db, `children/${g.childId}/communication_requests`));
  assert.equal(all.size, 1);
  assert.equal(all.docs[0].get('message'), 'Necesito agua');

  const tRef = doc(t.phone.db, `children/${g.childId}/communication_requests/${id}`);
  const step = (status, extra = {}) => {
    const batch = writeBatch(t.phone.db);
    batch.update(tRef, {
      status, statusUpdatedAt: serverTimestamp(), statusUpdatedByUid: t.user.uid,
      statusUpdatedByName: 'Ana', ...extra,
    });
    batch.set(doc(collection(tRef, 'events')), {
      type: status, byUid: t.user.uid, byName: 'Ana', at: serverTimestamp(),
    });
    return batch.commit();
  };
  await step('seen', { seenAt: serverTimestamp() });
  await step('attending', { attendingAt: serverTimestamp() });
  await rejects(updateDoc(tRef, {
    status: 'seen', statusUpdatedAt: serverTimestamp(), statusUpdatedByUid: t.user.uid,
  }));
  await rejects(updateDoc(tRef, {
    status: 'resolved', statusUpdatedAt: serverTimestamp(), statusUpdatedByUid: g.user.uid,
  }));
  await step('resolved', {
    resolvedAt: serverTimestamp(), supportProvided: 'Le acompañé por agua',
    supportByUid: t.user.uid, supportByName: 'Ana', supportAt: serverTimestamp(),
  });

  const fromFamily = await getDoc(ref);
  assert.equal(fromFamily.get('status'), 'resolved');
  assert.equal(fromFamily.get('supportProvided'), 'Le acompañé por agua');

  await rejects(updateDoc(ref, { childFeedback: 'excelente', childFeedbackAt: serverTimestamp() }));
  await updateDoc(ref, { childFeedback: 'better', childFeedbackAt: serverTimestamp() });
  const events = await getDocs(collection(tRef, 'events'));
  assert.equal(events.size, 3);
  await rejects(updateDoc(events.docs[0].ref, { byName: 'Cambiado' }));

  await new Promise((r) => setTimeout(r, 300));
  unsubscribe();
  assert.ok(seen.some(([type]) => type === 'added'), 'la docente recibió la solicitud en tiempo real');
  assert.ok(seen.some(([, status]) => status === 'resolved'));
});

test('13. Cambio de cuenta en el mismo teléfono: sin acceso a los datos anteriores', async () => {
  const g = await guardianWithChild();
  await signOut(g.phone.auth);
  await registerVerified(g.phone, { email: uniqueEmail('otra'), name: 'Otra', role: 'tutor' });
  await rejects(getDoc(doc(g.phone.db, `children/${g.childId}`)));
  await rejects(getDocs(collection(g.phone.db, `children/${g.childId}/communication_requests`)));
});

test('14. Accesos y cambios no autorizados se rechazan', async () => {
  const g = await guardianWithChild();
  const t = await teacherWithClass();
  const stranger = t.phone;
  await rejects(getDoc(doc(stranger.db, `children/${g.childId}`)));
  await rejects(getDoc(doc(stranger.db, `children/${g.childId}/sensory_passports/main`)));
  await rejects(getDocs(collection(stranger.db, `children/${g.childId}/communication_requests`)));
  await rejects(updateDoc(doc(stranger.db, `children/${g.childId}`), { memberUids: arrayUnion(t.user.uid) }));
  await rejects(setDoc(doc(stranger.db, `children/${g.childId}/caregiver_links/${t.user.uid}`), {
    childId: g.childId, adultUid: t.user.uid, permission: 'owner', role: 'docente',
  }));
  await rejects(setDoc(doc(stranger.db, 'join_requests/x'), { requesterUid: t.user.uid, status: 'approved' }));
  // Generar una invitación para la clase de otra persona.
  const other = await teacherWithClass();
  await rejects(createInvitation(t.phone, { type: 'classroom', targetId: other.classId }));
  // Revocar la invitación de otra persona.
  const theirs = await createInvitation(other.phone, { type: 'classroom', targetId: other.classId });
  await rejects(updateDoc(doc(t.phone.db, `group_invitations/${theirs}`), { revoked: true }));
  // Cambiar su rol en su perfil no le da acceso.
  await updateDoc(doc(t.phone.db, `users/${t.user.uid}`), { role: 'madre' });
  await rejects(getDoc(doc(t.phone.db, `children/${g.childId}`)));
});

test('15. Revocar una vinculación retira el acceso', async () => {
  const owner = device('familia-rev');
  const ownerUser = await registerVerified(owner, { email: uniqueEmail('rev'), name: 'Rosa', role: 'madre' });
  const familyId = await createFamily(owner, ownerUser, 'Familia Ruiz', 'Rosa');
  const code = await createInvitation(owner, { type: 'family', targetId: familyId });
  const other = device('familia-rev-b');
  await registerVerified(other, { email: uniqueEmail('rev-b'), name: 'Juan', role: 'padre' });
  await redeem(other, code);
  const [req] = await pendingFor(owner);
  await review(owner, req, true);
  assert.equal((await getDoc(doc(other.db, `families/${familyId}`))).exists(), true);
  await updateDoc(doc(owner.db, `families/${familyId}`), { adultUids: [ownerUser.uid] });
  await rejects(getDoc(doc(other.db, `families/${familyId}`)));

  const t = await teacherWithClass();
  const g = await guardianWithChild();
  await linkChildToClass(t, g);
  assert.equal((await getDoc(doc(t.phone.db, `children/${g.childId}`))).exists(), true);
  await updateDoc(doc(g.phone.db, `children/${g.childId}`), { memberUids: [g.user.uid] });
  await deleteDoc(doc(g.phone.db, `children/${g.childId}/caregiver_links/${t.user.uid}`));
  await rejects(getDoc(doc(t.phone.db, `children/${g.childId}`)));
});

test('8c. Un niño que ya está en otra clase de la docente se agrega a la nueva', async () => {
  const t = await teacherWithClass();
  const g = await guardianWithChild();
  await linkChildToClass(t, g);
  const secondClass = await createClass(t.phone, t.user, '2.º B', 'Ana');
  const code = await createInvitation(t.phone, { type: 'classroom', targetId: secondClass });
  await redeem(g.phone, code, g.childId);
  const [req] = await pendingFor(t.phone);
  // Ya es miembro: la app solo agrega la clase (sin volver a crear el vínculo).
  const batch = writeBatch(t.phone.db);
  batch.update(req.ref, { status: 'approved', reviewedAt: serverTimestamp() });
  batch.update(doc(t.phone.db, `classes/${secondClass}`), { studentIds: arrayUnion(g.childId) });
  batch.update(doc(t.phone.db, `children/${g.childId}`), {
    classIds: arrayUnion(secondClass), lastClassChange: secondClass,
  });
  batch.update(doc(t.phone.db, `children/${g.childId}/caregiver_links/${t.user.uid}`), {
    classIds: arrayUnion(secondClass),
  });
  await batch.commit();
  const child = await getDoc(doc(t.phone.db, `children/${g.childId}`));
  assert.deepEqual([...child.get('classIds')].sort(), [t.classId, secondClass].sort());
});
