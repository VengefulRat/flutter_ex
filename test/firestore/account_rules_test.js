// From this directory: firebase emulators:exec --project demo-lore-migration
// --only firestore --config firebase.json "node --test account_rules_test.js"
const assert = require('node:assert/strict');
const { test } = require('node:test');

const project = 'demo-lore-migration';
const base = `http://127.0.0.1:18764/v1/projects/${project}/databases/(default)/documents`;
const documentPrefix = `projects/${project}/databases/(default)/documents/`;

function token(uid, provider = 'password') {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    iss: `https://securetoken.google.com/${project}`,
    aud: project,
    sub: uid,
    user_id: uid,
    iat: now,
    exp: now + 3600,
    auth_time: now,
    firebase: { sign_in_provider: provider, identities: {} },
  })}.`;
}

function fields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, field(value)]),
  );
}

function field(value) {
  if (Array.isArray(value)) return { arrayValue: { values: value.map(field) } };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isSafeInteger(value)) return { integerValue: String(value) };
  return { stringValue: value };
}

async function request(path, { uid, provider, admin = false, method = 'GET', body } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(admin ? { Authorization: 'Bearer owner' } :
        uid ? { Authorization: `Bearer ${token(uid, provider)}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: response.status, text: await response.text() };
}

function write(path, data) {
  return { update: { name: documentPrefix + path, fields: fields(data) } };
}

async function commit(uid, writes, provider) {
  return request(':commit', { uid, provider, method: 'POST', body: { writes } });
}

function registration(uid, code, discoverable = true) {
  return [
    write(`accounts_v2/${uid}`, { code }),
    write(`profiles_v2/${code}`, {
      uid,
      code,
      displayName: uid,
      displayNameOriginal: uid,
      isDiscoverable: discoverable,
    }),
    write(`names_v2/${uid}`, { code }),
  ];
}

function expectStatus(result, expected) {
  assert.equal(result.status, expected, result.text);
}

test('new accounts bind a code to one password identity', async () => {
  const alice = registration('alice', 'LR-ABCD-EFGH');
  expectStatus(await commit('alice', alice), 200);
  expectStatus(await request('/accounts_v2/alice', { uid: 'alice' }), 200);
  expectStatus(await request('/accounts_v2/alice', { uid: 'bob' }), 403);
  expectStatus(await request('/accounts_v2/alice'), 403);
  expectStatus(
    await commit('bob', registration('bob', 'LR-ABCD-EFGH')),
    403,
  );
  expectStatus(
    await commit('anonymous', registration('anonymous', 'LR-ABCD-JKLM'), 'anonymous'),
    403,
  );
  expectStatus(
    await commit('alice', [write('accounts_v2/alice', { code: 'LR-ABCD-JKLM' })]),
    403,
  );
  expectStatus(
    await commit('charlie', [write('accounts_v2/charlie', { code: 'LR-ABCD-JKLM' })]),
    403,
  );
  expectStatus(
    await commit('charlie', registration('charlie', 'not-a-valid-code')),
    403,
  );
  const takenName = registration('charlie', 'LR-ABCD-JKLM');
  takenName[1] = write('profiles_v2/LR-ABCD-JKLM', {
    uid: 'charlie', code: 'LR-ABCD-JKLM', displayName: 'alice',
    displayNameOriginal: 'Alice', isDiscoverable: true,
  });
  takenName[2] = write('names_v2/alice', { code: 'LR-ABCD-JKLM' });
  expectStatus(await commit('charlie', takenName), 403);
});

test('private account data and diary entries are owner-only', async () => {
  const privateData = write('private_v2/alice/data/secrets', { pinHash: 'secret' });
  const diary = write('private_v2/alice/diary/entry', { text: 'private' });
  expectStatus(await commit('alice', [privateData, diary]), 200);
  expectStatus(await request('/private_v2/alice/diary/entry', { uid: 'alice' }), 200);
  expectStatus(await request('/private_v2/alice/data/secrets', { uid: 'bob' }), 403);
  expectStatus(await commit('bob', [privateData]), 403);
  expectStatus(await commit('alice', [diary], 'anonymous'), 403);
});

test('profiles cannot contain private fields or change ownership', async () => {
  const code = 'LR-ABCD-EFGH';
  const profile = {
    uid: 'alice',
    code,
    displayName: 'alice',
    displayNameOriginal: 'Alice',
    isDiscoverable: true,
  };
  expectStatus(await commit('alice', [write(`profiles_v2/${code}`, profile)]), 200);
  expectStatus(
    await commit('alice', [write(`profiles_v2/${code}`, { ...profile, pinHash: 'secret' })]),
    403,
  );
  expectStatus(
    await commit('alice', [write(`profiles_v2/${code}`, { ...profile, uid: 'bob' })]),
    403,
  );
  expectStatus(await commit('bob', [write(`profiles_v2/${code}`, profile)]), 403);
  expectStatus(await request(`/profiles_v2/${code}`, { uid: 'bob' }), 200);
  expectStatus(await request(`/profiles_v2/${code}`), 403);
});

test('identity public keys are bound atomically and cannot be replaced', async () => {
  const code = 'LR-ABCD-EFGH';
  const key = Buffer.alloc(32, 1).toString('base64');
  const profile = {
    uid: 'alice', code, displayName: 'alice',
    displayNameOriginal: 'Alice', isDiscoverable: true, publicKey: key,
  };
  const profileWrite = write(`profiles_v2/${code}`, profile);
  const identityWrite = write('private_v2/alice/data/identity', { publicKey: key });
  expectStatus(await commit('alice', [profileWrite]), 403);
  expectStatus(await commit('bob', [profileWrite, identityWrite]), 403);
  expectStatus(await commit('alice', [profileWrite, identityWrite]), 200);
  expectStatus(await request('/private_v2/alice/data/identity', { uid: 'bob' }), 403);
  expectStatus(await commit('alice', [write(`profiles_v2/${code}`, {
    ...profile, publicKey: Buffer.alloc(32, 2).toString('base64'),
  })]), 403);
  const withoutKey = { ...profile };
  delete withoutKey.publicKey;
  expectStatus(await commit('alice', [write(`profiles_v2/${code}`, withoutKey)]), 403);
});

test('discovery only lists profiles that opt in', async () => {
  expectStatus(
    await commit('bob', registration('bob', 'LR-JKLM-NPQR', false)),
    200,
  );
  const query = (where) => request(':runQuery', {
    uid: 'alice',
    method: 'POST',
    body: { structuredQuery: { from: [{ collectionId: 'profiles_v2' }], ...where } },
  });
  expectStatus(await query({}), 403);
  const result = await query({
    where: {
      fieldFilter: {
        field: { fieldPath: 'isDiscoverable' },
        op: 'EQUAL',
        value: { booleanValue: true },
      },
    },
  });
  expectStatus(result, 200);
  const profiles = JSON.parse(result.text)
    .filter((entry) => entry.document)
    .map((entry) => entry.document.fields.code.stringValue);
  assert.deepEqual(profiles, ['LR-ABCD-EFGH']);
});

test('unimplemented collections remain inaccessible', async () => {
  expectStatus(
    await commit('alice', [write('sessions/room', { content: 'story' })]),
    403,
  );
});

test('only an invited recipient can create a room by accepting a request', async () => {
  const alice = 'LR-ABCD-EFGH';
  const bob = 'LR-JKLM-NPQR';
  const charlie = 'LR-STUV-WXYZ';
  expectStatus(await commit('charlie', registration('charlie', charlie)), 200);

  const pending = { fromCode: alice, toCode: bob, status: 'pending' };
  const accepted = { ...pending, status: 'accepted', sessionId: 'room-1' };
  const room = { requestId: 'request-1', participants: [alice, bob] };
  expectStatus(
    await commit('alice', [write('interests_v2/request-1', pending)]),
    200,
  );
  expectStatus(
    await commit('charlie', [write('interests_v2/spoof', pending)]),
    403,
  );
  expectStatus(await request('/interests_v2/request-1', { uid: 'charlie' }), 403);
  expectStatus(
    await commit('bob', [write('interests_v2/request-1', accepted)]),
    403,
  );
  expectStatus(
    await commit('bob', [write('sessions_v2/room-1', room)]),
    403,
  );
  expectStatus(
    await commit('alice', [
      write('interests_v2/request-1', accepted),
      write('sessions_v2/room-1', room),
    ]),
    403,
  );
  expectStatus(
    await commit('bob', [
      write('interests_v2/request-1', accepted),
      write('sessions_v2/room-1', { ...room, participants: [bob, charlie] }),
    ]),
    403,
  );
  expectStatus(
    await commit('bob', [
      write('interests_v2/request-1', accepted),
      write('sessions_v2/room-1', room),
    ]),
    200,
  );
  expectStatus(await request('/sessions_v2/room-1', { uid: 'alice' }), 200);
  expectStatus(await request('/sessions_v2/room-1', { uid: 'bob' }), 200);
  expectStatus(await request('/sessions_v2/room-1', { uid: 'charlie' }), 403);
  const query = (where) => request(':runQuery', {
    uid: 'alice',
    method: 'POST',
    body: { structuredQuery: { from: [{ collectionId: 'sessions_v2' }], ...where } },
  });
  expectStatus(await query({}), 403);
  const listed = await query({
    where: {
      fieldFilter: {
        field: { fieldPath: 'participants' },
        op: 'ARRAY_CONTAINS',
        value: { stringValue: alice },
      },
    },
  });
  expectStatus(listed, 200);
  assert.equal(JSON.parse(listed.text).filter((entry) => entry.document).length, 1);
  expectStatus(
    await commit('alice', [write('sessions_v2/room-1', {
      ...room, participants: [alice, charlie],
    })]),
    403,
  );
});

test('room-key envelopes are created together and visible only to participants', async () => {
  const alice = 'LR-ABCD-EFGH';
  const bob = 'LR-JKLM-NPQR';
  const bobKey = Buffer.alloc(32, 2).toString('base64');
  expectStatus(await commit('bob', [
    write(`profiles_v2/${bob}`, {
      uid: 'bob', code: bob, displayName: 'bob', displayNameOriginal: 'bob',
      isDiscoverable: false, publicKey: bobKey,
    }),
    write('private_v2/bob/data/identity', { publicKey: bobKey }),
  ]), 200);
  const envelope = {
    version: 1,
    ephemeralPublicKey: Buffer.alloc(32, 3).toString('base64'),
    nonce: Buffer.alloc(12, 4).toString('base64'),
    ciphertext: Buffer.alloc(48, 5).toString('base64'),
  };
  const alicePath = `sessions_v2/room-1/keys/${alice}`;
  const bobPath = `sessions_v2/room-1/keys/${bob}`;
  expectStatus(await commit('alice', [write('sessions_v2/room-1/posts/no-key', {
    authorCode: alice, authorName: 'Alice', encrypted: true,
    content: 'AAAAAAAAAAAAAAAAAAAAAA==', contentIv: 'AAAAAAAAAAAAAAAA',
    createdAt: new Date('2025-01-01T00:00:00.000Z'),
  })]), 403);
  expectStatus(await commit('alice', [write(alicePath, envelope)]), 403);
  expectStatus(await commit('charlie', [write(alicePath, envelope), write(bobPath, envelope)]), 403);
  expectStatus(await commit('alice', [write(alicePath, envelope), write(bobPath, envelope)]), 200);
  expectStatus(await request(`/${bobPath}`, { uid: 'alice' }), 200);
  expectStatus(await request(`/${bobPath}`, { uid: 'bob' }), 200);
  expectStatus(await request(`/${bobPath}`, { uid: 'charlie' }), 403);
  expectStatus(await commit('bob', [write(bobPath, envelope)]), 403);
  expectStatus(await commit('alice', [{ delete: documentPrefix + alicePath }]), 403);
});

test('only participants can read posts and only their author can change them', async () => {
  const post = {
    authorCode: 'LR-ABCD-EFGH',
    authorName: 'Alice',
    content: 'AAAAAAAAAAAAAAAAAAAAAA==',
    contentIv: 'AAAAAAAAAAAAAAAA',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    encrypted: true,
  };
  const path = 'sessions_v2/room-1/posts/post-1';
  expectStatus(await commit('alice', [write(path, post)]), 200);
  expectStatus(await request(`/${path}`, { uid: 'bob' }), 200);
  expectStatus(await request(`/${path}`, { uid: 'charlie' }), 403);
  expectStatus(await commit('bob', [write(path, { ...post, content: 'BBBBBBBBBBBBBBBBBBBBBB==' })]), 403);
  expectStatus(await commit('alice', [write(path, { ...post, content: 'BBBBBBBBBBBBBBBBBBBBBB==' })]), 200);
  expectStatus(await commit('bob', [write('sessions_v2/room-1/posts/forged', post)]), 403);
  expectStatus(await commit('bob', [write('sessions_v2/room-1/posts/forged-name', {
    ...post, authorCode: 'LR-JKLM-NPQR',
  })]), 403);
  expectStatus(await commit('charlie', [write('sessions_v2/room-1/posts/outsider', post)]), 403);
  expectStatus(await commit('alice', [write('sessions_v2/room-1/posts/plain', { ...post, encrypted: false })]), 403);
  expectStatus(await commit('alice', [write('sessions_v2/room-1/posts/bad-iv', { ...post, contentIv: 'not-an-iv' })]), 403);
  expectStatus(await commit('alice', [write('sessions_v2/room-1/posts/delta', { ...post, contentDelta: 'plaintext' })]), 403);
  expectStatus(await commit('bob', [{ delete: documentPrefix + path }]), 403);
  expectStatus(await commit('alice', [{ delete: documentPrefix + path }]), 200);
});

test('a restore requires the other participant to approve frozen posts', async () => {
  const statePath = 'sessions_v2/room-1/restore/state';
  const stagedPath = `${statePath}/posts/old-post`;
  const metadataPath = `${statePath}/metadata/000000`;
  const livePath = 'sessions_v2/room-1/posts/old-post';
  const liveMetadataPath = 'sessions_v2/room-1/story_metadata/000000';
  const state = {
    status: 'uploading',
    importerCode: 'LR-ABCD-EFGH',
    reviewerCode: 'LR-JKLM-NPQR',
    postCount: 1,
    metadataCount: 1,
    reviewVersion: 0,
    decisionVersion: 0,
  };
  const post = {
    authorCode: 'LR-JKLM-NPQR',
    authorName: 'Earlier pen name',
    content: 'AAAAAAAAAAAAAAAAAAAAAA==',
    contentIv: 'AAAAAAAAAAAAAAAA',
    contentRuns: null,
    quotedContent: null,
    characterName: null,
    locationName: null,
    textColor: null,
    quotedPostId: null,
    quotedAuthor: null,
    chapter: 'Chapter 1',
    edited: false,
    createdAt: new Date('2025-01-01T00:00:00.000Z'),
    encrypted: true,
  };
  expectStatus(await commit('bob', [write(statePath, state)]), 403);
  expectStatus(await commit('alice', [write(statePath, state)]), 200);
  expectStatus(await commit('alice', [write(stagedPath, post)]), 200);
  const metadata = { cipher: 'AAAAAAAAAAAAAAAAAAAAAA==', iv: 'AAAAAAAAAAAAAAAA' };
  expectStatus(await commit('alice', [write(metadataPath, metadata)]), 200);
  expectStatus(await commit('bob', [write(metadataPath, metadata)]), 403);
  expectStatus(await request(`/${metadataPath}`, { uid: 'charlie' }), 403);
  expectStatus(await request(`/${stagedPath}`, { uid: 'bob' }), 200);
  expectStatus(await request(`/${stagedPath}`, { uid: 'charlie' }), 403);
  expectStatus(await commit('alice', [write(livePath, post)]), 403);
  expectStatus(await commit('bob', [write(statePath, {
    ...state, status: 'approved', decisionVersion: 1,
  })]), 403);

  expectStatus(await commit('alice', [write(statePath, { ...state, status: 'review' })]), 403);
  expectStatus(await commit('alice', [write(statePath, {
    ...state, status: 'review', reviewVersion: 1,
  })]), 403);
  const verifying = { ...state, status: 'verifying', reviewVersion: 1 };
  expectStatus(await commit('alice', [write(statePath, verifying)]), 200);
  expectStatus(await commit('alice', [write(stagedPath, {
    ...post, content: 'BBBBBBBBBBBBBBBBBBBBBB==',
  })]), 403);
  expectStatus(await commit('alice', [write(metadataPath, metadata)]), 403);
  expectStatus(await commit('bob', [write(statePath, { ...verifying, status: 'review' })]), 403);
  const resumedUpload = { ...verifying, status: 'uploading' };
  expectStatus(await commit('alice', [write(statePath, resumedUpload)]), 200);
  expectStatus(await commit('alice', [write(statePath, verifying)]), 403);
  const resumedVerification = { ...resumedUpload, status: 'verifying', reviewVersion: 2 };
  expectStatus(await commit('alice', [write(statePath, resumedVerification)]), 200);
  const review = { ...resumedVerification, status: 'review' };
  expectStatus(await commit('alice', [write(statePath, review)]), 200);
  expectStatus(await commit('alice', [write(stagedPath, { ...post, content: 'BBBBBBBBBBBBBBBBBBBBBB==' })]), 403);
  expectStatus(await commit('alice', [write(statePath, {
    ...review, status: 'approved', decisionVersion: 2,
  })]), 403);
  expectStatus(await commit('charlie', [write(statePath, {
    ...review, status: 'approved', decisionVersion: 2,
  })]), 403);
  expectStatus(await commit('bob', [write(statePath, { ...review, status: 'rejected' })]), 403);
  expectStatus(await commit('bob', [write(statePath, {
    ...review, status: 'rejected', decisionVersion: 2,
  })]), 200);
  expectStatus(await commit('alice', [write(livePath, post)]), 403);
  const retry = { ...review, status: 'uploading', decisionVersion: 2 };
  expectStatus(await commit('alice', [write(statePath, retry)]), 200);
  const revisedPost = { ...post, content: 'BBBBBBBBBBBBBBBBBBBBBB==' };
  expectStatus(await commit('alice', [write(stagedPath, revisedPost)]), 200);
  expectStatus(await commit('alice', [write(statePath, review)]), 403);
  const nextVerification = { ...retry, status: 'verifying', reviewVersion: 3 };
  expectStatus(await commit('alice', [write(statePath, nextVerification)]), 200);
  const nextReview = { ...nextVerification, status: 'review' };
  expectStatus(await commit('alice', [write(statePath, nextReview)]), 200);
  expectStatus(await commit('bob', [write(statePath, { ...nextReview, status: 'approved' })]), 403);
  expectStatus(await commit('bob', [write(statePath, {
    ...nextReview, status: 'approved', decisionVersion: 2,
  })]), 403);
  expectStatus(await commit('bob', [write(statePath, {
    ...nextReview, status: 'rejected', decisionVersion: 2,
  })]), 403);
  const approved = { ...nextReview, status: 'approved', decisionVersion: 3 };
  expectStatus(await commit('bob', [write(statePath, approved)]), 200);
  expectStatus(await commit('alice', [write(livePath, post)]), 403);
  expectStatus(await commit('alice', [write(livePath, revisedPost)]), 200);
  expectStatus(await request(`/${livePath}`, { uid: 'alice' }), 200);
  expectStatus(await request(`/${livePath}`, { uid: 'bob' }), 403);
  expectStatus(await commit('alice', [write(liveMetadataPath, {
    ...metadata, cipher: 'BBBBBBBBBBBBBBBBBBBBBB==',
  })]), 403);
  expectStatus(await commit('alice', [write(liveMetadataPath, metadata)]), 200);
  expectStatus(await request(`/${liveMetadataPath}`, { uid: 'bob' }), 403);
  expectStatus(await commit('bob', [write(livePath, { ...post, content: 'BBBBBBBBBBBBBBBBBBBBBB==' })]), 403);
  expectStatus(await commit('bob', [write(statePath, { ...approved, status: 'completed' })]), 403);

  expectStatus(await commit('alice', [write(statePath, { ...approved, status: 'completed' })]), 403);
  expectStatus(await request(':commit', {
    admin: true, method: 'POST',
    body: { writes: [write(statePath, { ...approved, status: 'completed' })] },
  }), 200);
  expectStatus(await request(`/${livePath}`, { uid: 'bob' }), 200);
  expectStatus(await request(`/${liveMetadataPath}`, { uid: 'bob' }), 200);
  expectStatus(await commit('bob', [write(livePath, { ...post, content: 'CCCCCCCCCCCCCCCCCCCCCC==' })]), 200);
  expectStatus(await commit('bob', [{ delete: documentPrefix + livePath }]), 200);
  expectStatus(await commit('alice', [write(livePath, post)]), 403);
});

test('a full upload batch fits the staged rules access limits', async () => {
  const alice = 'LR-ABCD-EFGH';
  const bob = 'LR-JKLM-NPQR';
  const requestId = 'batch-request';
  const roomId = 'batch-room';
  const pending = { fromCode: alice, toCode: bob, status: 'pending' };
  expectStatus(await commit('alice', [write(`interests_v2/${requestId}`, pending)]), 200);
  expectStatus(await commit('bob', [
    write(`interests_v2/${requestId}`, { ...pending, status: 'accepted', sessionId: roomId }),
    write(`sessions_v2/${roomId}`, { requestId, participants: [alice, bob] }),
  ]), 200);
  const envelope = {
    version: 1, ephemeralPublicKey: Buffer.alloc(32, 3).toString('base64'),
    nonce: Buffer.alloc(12, 4).toString('base64'),
    ciphertext: Buffer.alloc(48, 5).toString('base64'),
  };
  expectStatus(await commit('alice', [
    write(`sessions_v2/${roomId}/keys/${alice}`, envelope),
    write(`sessions_v2/${roomId}/keys/${bob}`, envelope),
  ]), 200);
  const statePath = `sessions_v2/${roomId}/restore/state`;
  const state = {
    status: 'uploading', importerCode: alice, reviewerCode: bob,
    postCount: 400, metadataCount: 1, reviewVersion: 0, decisionVersion: 0,
  };
  expectStatus(await commit('alice', [write(statePath, state)]), 200);
  const post = {
    authorCode: bob, authorName: 'Writer', encrypted: true,
    content: 'AAAAAAAAAAAAAAAAAAAAAA==', contentIv: 'AAAAAAAAAAAAAAAA',
    createdAt: new Date('2025-01-01T00:00:00.000Z'),
  };
  expectStatus(await commit('alice', Array.from({ length: 400 }, (_, i) =>
    write(`${statePath}/posts/post-${i}`, post),
  )), 200);
  const metadata = { cipher: 'AAAAAAAAAAAAAAAAAAAAAA==', iv: 'AAAAAAAAAAAAAAAA' };
  expectStatus(await commit('alice', [write(`${statePath}/metadata/000000`, metadata)]), 200);
  const verifying = { ...state, status: 'verifying', reviewVersion: 1 };
  const review = { ...verifying, status: 'review' };
  expectStatus(await commit('alice', [write(statePath, verifying)]), 200);
  expectStatus(await commit('alice', [write(statePath, review)]), 200);
  expectStatus(await commit('bob', [write(statePath, {
    ...review, status: 'approved', decisionVersion: 1,
  })]), 200);
  expectStatus(await commit('alice', Array.from({ length: 10 }, (_, i) =>
    write(`sessions_v2/${roomId}/posts/post-${i}`, post),
  )), 200);
});
