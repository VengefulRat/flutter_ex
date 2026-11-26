// Emulator-only prototype. This is not a deployable production function.
const { isDeepStrictEqual } = require('node:util');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldPath } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

initializeApp();
const db = getFirestore();

function assertEmulator() {
  if (process.env.FUNCTIONS_EMULATOR !== 'true' ||
      process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:18764' ||
      process.env.GCLOUD_PROJECT !== 'demo-lore-migration') {
    throw new HttpsError('failed-precondition', 'This function is emulator-only.');
  }
}

function checkState(state, account, room, version) {
  const participants = room?.participants;
  if (!state || !account || typeof account.code !== 'string' ||
      !Array.isArray(participants) || participants.length !== 2 ||
      participants.some((participant) => typeof participant !== 'string') ||
      participants[0] === participants[1] ||
      !participants.includes(account.code) ||
      state.importerCode !== account.code ||
      !participants.includes(state.reviewerCode) ||
      state.reviewerCode === account.code ||
      !Number.isSafeInteger(state.postCount) || state.postCount < 0 ||
      !Number.isSafeInteger(state.metadataCount) || state.metadataCount < 1 ||
      state.metadataCount > 1000000 ||
      state.reviewVersion !== version || state.decisionVersion !== version ||
      !['approved', 'completed'].includes(state.status)) {
    throw new HttpsError('failed-precondition', 'Restore is not approved for this account and version.');
  }
}

async function compareCollections(staged, live, expectedCount) {
  let cursor = null;
  let count = 0;
  for (;;) {
    let stagedQuery = staged.orderBy(FieldPath.documentId()).limit(100);
    let liveQuery = live.orderBy(FieldPath.documentId()).limit(100);
    if (cursor !== null) {
      stagedQuery = stagedQuery.startAfter(cursor);
      liveQuery = liveQuery.startAfter(cursor);
    }
    const [expected, actual] = await Promise.all([stagedQuery.get(), liveQuery.get()]);
    if (expected.size !== actual.size) {
      throw new HttpsError('failed-precondition', 'Published documents do not match the approved restore.');
    }
    for (let i = 0; i < expected.size; i++) {
      const source = expected.docs[i];
      const target = actual.docs[i];
      if (source.id !== target.id || !isDeepStrictEqual(source.data(), target.data())) {
        throw new HttpsError('failed-precondition', 'Published documents do not match the approved restore.');
      }
    }
    count += expected.size;
    if (count > expectedCount) {
      throw new HttpsError('failed-precondition', 'Approved document count does not match.');
    }
    if (expected.size < 100) break;
    cursor = expected.docs[expected.size - 1].id;
  }
  if (count !== expectedCount) {
    throw new HttpsError('failed-precondition', 'Approved document count does not match.');
  }
}

exports.finalizeStagedRestore = onCall({ timeoutSeconds: 540 }, async (request) => {
  assertEmulator();
  if (!request.auth || request.auth.token.firebase?.sign_in_provider !== 'password') {
    throw new HttpsError('unauthenticated', 'Password authentication is required.');
  }
  const { sessionId, reviewVersion } = request.data ?? {};
  if (typeof sessionId !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(sessionId) ||
      !Number.isSafeInteger(reviewVersion) || reviewVersion < 1) {
    throw new HttpsError('invalid-argument', 'Invalid room or review version.');
  }
  const accountRef = db.collection('accounts_v2').doc(request.auth.uid);
  const roomRef = db.collection('sessions_v2').doc(sessionId);
  const stateRef = roomRef.collection('restore').doc('state');
  const [account, room, state] = await Promise.all([
    accountRef.get(), roomRef.get(), stateRef.get(),
  ]);
  const original = state.data();
  checkState(original, account.data(), room.data(), reviewVersion);
  if (original.status === 'completed') return { status: 'completed' };

  // The rules freeze staged documents and allow only exact staged copies to be
  // created in the live collections while the state remains approved.
  await compareCollections(stateRef.collection('posts'), roomRef.collection('posts'), original.postCount);
  await compareCollections(stateRef.collection('metadata'), roomRef.collection('story_metadata'), original.metadataCount);
  await db.runTransaction(async (tx) => {
    const [currentAccount, currentRoom, currentState] = await Promise.all([
      tx.get(accountRef), tx.get(roomRef), tx.get(stateRef),
    ]);
    const current = currentState.data();
    checkState(current, currentAccount.data(), currentRoom.data(), reviewVersion);
    if (!isDeepStrictEqual(current, original)) {
      if (current.status === 'completed' &&
          isDeepStrictEqual({ ...current, status: 'approved' }, original)) return;
      throw new HttpsError('aborted', 'Restore changed while being finalized.');
    }
    tx.update(stateRef, { status: 'completed' });
  });
  return { status: 'completed' };
});
