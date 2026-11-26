// Utilidades para simular dispositivos independientes contra los emuladores.
//
// Cada "dispositivo" es una instancia propia del SDK cliente de Firebase
// (como la app en un teléfono): tiene su propia sesión, pasa por las reglas
// de seguridad y llama a las Cloud Functions por HTTPS. Los datos siguen la
// misma forma que escriben los repositorios `firebase_*` de la app.
import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth, connectAuthEmulator, createUserWithEmailAndPassword,
  signInWithEmailAndPassword, sendEmailVerification, sendPasswordResetEmail,
  signOut,
} from 'firebase/auth';
import {
  getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, writeBatch,
  serverTimestamp, terminate,
} from 'firebase/firestore';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';

export const PROJECT = 'demo-mivoz';
const HOST = '127.0.0.1';
const AUTH = `http://${HOST}:9099`;
const FIRESTORE = `http://${HOST}:8080`;

let counter = 0;

/** Un teléfono con la app instalada (sin sesión). */
export function newDevice(label = 'dispositivo') {
  const app = initializeApp(
    { apiKey: 'demo-key', projectId: PROJECT, appId: `1:1:web:${label}` },
    `${label}-${++counter}`,
  );
  const auth = getAuth(app);
  connectAuthEmulator(auth, AUTH, { disableWarnings: true });
  // Misma base con nombre que la app y las funciones.
  const db = getFirestore(app, 'mivoz');
  connectFirestoreEmulator(db, HOST, 8080);
  const functions = getFunctions(app, 'us-central1');
  connectFunctionsEmulator(functions, HOST, 5001);
  return {
    app, auth, db, functions,
    call: (name, data) => httpsCallable(functions, name)(data).then((r) => r.data),
    async close() {
      await terminate(db).catch(() => {});
      await deleteApp(app).catch(() => {});
    },
  };
}

export function uniqueEmail(prefix) {
  return `${prefix}.${Date.now()}.${++counter}@ejemplo.test`;
}

/**
 * Registro como lo hace la app: cuenta de Auth + `users/{uid}` (sin
 * contraseña) + correo de verificación.
 */
export async function register(device, { email, password = 'clave1234', name, role }) {
  const cred = await createUserWithEmailAndPassword(device.auth, email, password);
  await setDoc(doc(device.db, `users/${cred.user.uid}`), {
    uid: cred.user.uid,
    email,
    displayName: name,
    role,
    experiences: [role === 'docente' ? 'teacher' : 'guardian'],
    createdAt: serverTimestamp(),
  });
  device.auth.languageCode = 'es';
  await sendEmailVerification(cred.user);
  return cred.user;
}

/** Correos que el emulador de Auth "envió" (verificación, contraseña). */
export async function oobCodes(email) {
  const res = await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/oobCodes`);
  const { oobCodes: codes = [] } = await res.json();
  return codes.filter((c) => c.email === email);
}

/** El usuario abre el enlace del correo de verificación. */
export async function clickVerificationLink(email) {
  const codes = (await oobCodes(email)).filter((c) => c.requestType === 'VERIFY_EMAIL');
  if (!codes.length) throw new Error(`No se envió verificación a ${email}`);
  const res = await fetch(codes[codes.length - 1].oobLink);
  if (!res.ok) throw new Error(`Enlace de verificación falló: ${res.status}`);
}

/** Recarga el usuario y fuerza un token nuevo (lo que hace "Ya confirmé"). */
export async function refreshVerification(device) {
  await device.auth.currentUser.reload();
  await device.auth.currentUser.getIdToken(true);
  return device.auth.currentUser.emailVerified;
}

export async function registerVerified(device, opts) {
  const user = await register(device, opts);
  await clickVerificationLink(opts.email);
  await refreshVerification(device);
  return user;
}

export { signInWithEmailAndPassword, sendPasswordResetEmail, signOut, doc, getDoc, setDoc, writeBatch, serverTimestamp };

/** Familia como `FirebaseFamiliesRepository.createFamily`. */
export async function createFamily(device, user, name, displayName) {
  const id = `fam-${++counter}-${Date.now()}`;
  await setDoc(doc(device.db, `families/${id}`), {
    id, name, ownerUid: user.uid, adultUids: [user.uid],
    adultNames: { [user.uid]: displayName }, adultRoles: { [user.uid]: 'madre' },
    createdAt: serverTimestamp(),
  });
  return id;
}

/** Clase como `FirebaseClassesRepository.createClass`. */
export async function createClass(device, user, name, displayName) {
  const id = `cls-${++counter}-${Date.now()}`;
  await setDoc(doc(device.db, `classes/${id}`), {
    id, name, description: '', ownerUid: user.uid, teacherUids: [user.uid],
    teacherNames: { [user.uid]: displayName }, studentIds: [], archived: false,
    createdAt: serverTimestamp(),
  });
  return id;
}

/** Perfil infantil sin familia, como `FirebaseChildrenRepository.createChild`. */
export async function createChild(device, user, name, displayName) {
  const id = `nino-${++counter}-${Date.now()}`;
  const batch = writeBatch(device.db);
  batch.set(doc(device.db, `children/${id}`), {
    id, name, avatar: 'animal_lion', avatarColor: 0, gender: 'masculine',
    ownerUid: user.uid, memberUids: [user.uid], familyId: null, classIds: [],
    noCompanionRule: 'admin', backupUids: [], settings: {},
    createdAt: serverTimestamp(),
  });
  batch.set(doc(device.db, `children/${id}/caregiver_links/${user.uid}`), {
    childId: id, adultUid: user.uid, adultName: displayName, adultEmail: '',
    role: 'madre', permission: 'owner', source: 'direct', classIds: [],
    receivesRequests: true, canViewPassport: true, createdAt: serverTimestamp(),
  });
  await batch.commit();
  return id;
}

/** Solicitud como `CommunicationRequest.toCreateMap` + entrega. */
export function requestData(childId, uid, id, message = 'Necesito agua') {
  return {
    id, childId, childName: 'Leo', categoryId: 'necesito',
    categoryTitle: 'NECESITO', message, emoji: 'necesito_agua',
    pictogramIds: ['necesito_agua'], priority: 'normal', isUrgent: false,
    recipientUid: null, recipientName: null, createdByUid: uid,
    createdAt: new Date(), status: 'new', serverReceivedAt: serverTimestamp(),
  };
}

/** Espera el rechazo de una operación y devuelve el error. */
export async function rejects(promise) {
  try {
    await promise;
  } catch (e) {
    return e;
  }
  throw new Error('Se esperaba un rechazo y la operación se permitió.');
}

/** Motivo (`reason`) que devuelven las Cloud Functions de invitaciones. */
export function reason(err) {
  return err?.details?.reason ?? err?.code;
}

export async function firestoreAdminPatch(path, fields) {
  // Ajuste directo en el emulador saltando las reglas (equivale a la consola):
  // solo para simular el paso del tiempo (invitación vencida).
  const res = await fetch(
    `${FIRESTORE}/v1/projects/${PROJECT}/databases/mivoz/documents/${path}?${Object.keys(fields).map((k) => `updateMask.fieldPaths=${k}`).join('&')}`,
    {
      method: 'PATCH',
      headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    },
  );
  if (!res.ok) throw new Error(`patch ${path}: ${res.status} ${await res.text()}`);
}
