// Invitaciones sin Cloud Functions, igual que
// lib/features/invitations/data/firebase_invitations_repository.dart:
// transacciones del cliente que las reglas de Firestore validan.
import {
  doc, getDoc, runTransaction, writeBatch, collection, query, where, getDocs,
  serverTimestamp, arrayUnion,
} from 'firebase/firestore';

const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

export function randomCode() {
  let c = '';
  for (let i = 0; i < 8; i++) c += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  return c;
}

export function normalize(raw) {
  return String(raw).trim().toUpperCase().replace(/[\s-]/g, '');
}

export class InvitationError extends Error {
  constructor(reason) {
    super(reason);
    this.reason = reason;
  }
}

function statusOf(d, now = Date.now()) {
  if (d.revoked) return 'revoked';
  if ((d.uses || 0) >= (d.maxUses || 1)) return 'exhausted';
  const created = d.createdAt?.toMillis ? d.createdAt.toMillis() : now;
  if (created + d.validityHours * 3600e3 <= now) return 'expired';
  return 'active';
}

export async function createInvitation(device, { type, targetId, validityHours = 48, maxUses = 1, role = null, code }) {
  const uid = device.auth.currentUser.uid;
  const target = await getDoc(doc(device.db, `${type === 'family' ? 'families' : 'classes'}/${targetId}`));
  const me = await getDoc(doc(device.db, `users/${uid}`));
  const c = code ?? randomCode();
  const ref = doc(device.db, `group_invitations/${c}`);
  await runTransaction(device.db, async (tx) => {
    if ((await tx.get(ref)).exists()) throw new Error('código repetido');
    tx.set(ref, {
      code: c, type, targetId, targetName: target.get('name'), ownerUid: uid,
      createdBy: uid, createdByName: me.get('displayName') ?? 'Adulto',
      createdAt: serverTimestamp(), validityHours, maxUses, uses: 0,
      revoked: false, requiresApproval: true,
      role: type === 'family' ? (role ?? 'tutor') : null, lastRequestId: null,
    });
  });
  return c;
}

export async function preview(device, raw) {
  const code = normalize(raw);
  const snap = await getDoc(doc(device.db, `group_invitations/${code}`));
  if (!snap.exists()) throw new InvitationError('invalid');
  const st = statusOf(snap.data());
  if (st !== 'active') throw new InvitationError(st);
  return snap.data();
}

export function requestIdFor(uid, targetId, childId) {
  return `${uid}_${targetId}_${childId ?? 'adulto'}`;
}

export async function redeem(device, raw, childId = null) {
  const uid = device.auth.currentUser.uid;
  const inv = await preview(device, raw);
  const kid = inv.type === 'classroom' ? childId : null;
  let childName = null;
  if (kid) childName = (await getDoc(doc(device.db, `children/${kid}`))).get('name');
  const me = await getDoc(doc(device.db, `users/${uid}`));
  const rid = requestIdFor(uid, inv.targetId, kid);
  const invRef = doc(device.db, `group_invitations/${inv.code}`);
  const reqRef = doc(device.db, `join_requests/${rid}`);
  await runTransaction(device.db, async (tx) => {
    const fresh = await tx.get(invRef);
    const existing = await tx.get(reqRef);
    const st = statusOf(fresh.data());
    if (st !== 'active') throw new InvitationError(st);
    if (existing.exists() && existing.get('status') === 'pending') throw new InvitationError('alreadyRequested');
    tx.update(invRef, { uses: fresh.get('uses') + 1, lastRequestId: rid });
    tx.set(reqRef, {
      id: rid, code: inv.code, type: inv.type, targetId: inv.targetId,
      targetName: inv.targetName, requesterUid: uid,
      requesterName: me.get('displayName') ?? 'Adulto', approverUid: fresh.get('ownerUid'),
      childId: kid, childName, role: inv.role ?? null, status: 'pending',
      createdAt: serverTimestamp(), reviewedAt: null,
    });
  });
  return rid;
}

export async function pendingFor(device) {
  const uid = device.auth.currentUser.uid;
  const q = query(collection(device.db, 'join_requests'), where('approverUid', '==', uid), where('status', '==', 'pending'));
  return (await getDocs(q)).docs;
}

/** Aprobar o rechazar como lo hace la app. */
export async function review(device, reqSnap, approve) {
  const uid = device.auth.currentUser.uid;
  const r = reqSnap.data();
  const reqRef = reqSnap.ref;
  const reviewed = { status: approve ? 'approved' : 'rejected', reviewedAt: serverTimestamp() };
  if (!approve) {
    const b = writeBatch(device.db);
    b.update(reqRef, reviewed);
    return b.commit();
  }
  const batch = writeBatch(device.db);
  batch.update(reqRef, reviewed);
  if (r.type === 'family') {
    const kids = await getDocs(query(collection(device.db, 'children'), where('memberUids', 'array-contains', uid), where('familyId', '==', r.targetId)));
    batch.update(doc(device.db, `families/${r.targetId}`), {
      adultUids: arrayUnion(r.requesterUid),
      [`adultNames.${r.requesterUid}`]: r.requesterName,
      [`adultRoles.${r.requesterUid}`]: r.role ?? 'tutor',
      lastJoinRequest: reqSnap.id,
    });
    for (const k of kids.docs) {
      batch.update(k.ref, { memberUids: arrayUnion(r.requesterUid) });
      batch.set(doc(device.db, `children/${k.id}/caregiver_links/${r.requesterUid}`), {
        childId: k.id, adultUid: r.requesterUid, adultName: r.requesterName,
        adultEmail: '', role: r.role ?? 'tutor', permission: 'caregiver',
        source: 'family', classIds: [], receivesRequests: true,
        canViewPassport: true, invitedByUid: uid, createdAt: serverTimestamp(),
      });
    }
  } else {
    batch.update(doc(device.db, `classes/${r.targetId}`), { studentIds: arrayUnion(r.childId) });
    batch.update(doc(device.db, `children/${r.childId}`), {
      classIds: arrayUnion(r.targetId), memberUids: arrayUnion(uid),
      lastClassChange: r.targetId, lastJoinRequest: reqSnap.id,
    });
    batch.set(doc(device.db, `children/${r.childId}/caregiver_links/${uid}`), {
      childId: r.childId, adultUid: uid, adultName: 'Docente', adultEmail: '',
      role: 'docente', permission: 'caregiver', source: 'classroom',
      classIds: [r.targetId], receivesRequests: true, canViewPassport: true,
      invitedByUid: r.requesterUid, createdAt: serverTimestamp(),
    });
  }
  return batch.commit();
}
