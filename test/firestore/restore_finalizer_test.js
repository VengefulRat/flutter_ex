// Run with the Auth, Firestore and Functions emulators for demo-lore-migration.
const assert = require('node:assert/strict');
const { test } = require('node:test');

const project = 'demo-lore-migration';
const database = `projects/${project}/databases/(default)/documents`;
const firestore = `http://127.0.0.1:18764/v1/${database}`;
const auth = 'http://127.0.0.1:18765/identitytoolkit.googleapis.com/v1';
const callable = `http://127.0.0.1:18766/${project}/us-central1/finalizeStagedRestore`;
const room = 'sessions_v2/restore-test';
const state = `${room}/restore/state`;

function field(value) {
  if (Array.isArray(value)) return { arrayValue: { values: value.map(field) } };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (typeof value === 'boolean') return { booleanValue: value };
  return { stringValue: value };
}

function write(path, data) {
  return {
    update: {
      name: `${database}/${path}`,
      fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, field(v)])),
    },
  };
}

async function post(url, data, token) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(data),
  });
  return { status: response.status, data: await response.json() };
}

async function commit(writes, token = 'owner') {
  const result = await post(`${firestore}:commit`, { writes }, token);
  assert.equal(result.status, 200, JSON.stringify(result.data));
}

async function signup(name) {
  const result = await post(`${auth}/accounts:signUp?key=demo-key`, {
    email: `${name}@example.invalid`,
    password: 'emulator-password',
    returnSecureToken: true,
  });
  assert.equal(result.status, 200, JSON.stringify(result.data));
  return result.data;
}

async function finalize(token, reviewVersion = 1) {
  return post(callable, { data: { sessionId: 'restore-test', reviewVersion } }, token);
}

test('only the importer can finalize an exact approved published set', async () => {
  const alice = await signup('finalizer-alice');
  const bob = await signup('finalizer-bob');
  const anonymous = await post(`${auth}/accounts:signUp?key=demo-key`, {
    returnSecureToken: true,
  });
  assert.equal(anonymous.status, 200, JSON.stringify(anonymous.data));
  const aliceCode = 'LR-ABCD-EFGH';
  const bobCode = 'LR-JKLM-NPQR';
  const approved = {
    status: 'approved', importerCode: aliceCode, reviewerCode: bobCode,
    postCount: 105, metadataCount: 1, reviewVersion: 1, decisionVersion: 1,
  };
  const createdAt = new Date('2025-01-01T00:00:00.000Z');
  const nonce = Buffer.alloc(12).toString('base64');
  const cipher = (i) => Buffer.alloc(16, i).toString('base64');
  const metadata = { cipher: cipher(0), iv: nonce };
  const postData = (i) => ({
    authorCode: bobCode,
    authorName: 'Earlier name',
    content: cipher(i),
    contentIv: nonce,
    createdAt,
    encrypted: true,
  });
  async function register(user, code, name) {
    await commit([
      write(`accounts_v2/${user.localId}`, { code }),
      write(`profiles_v2/${code}`, {
        uid: user.localId, code, displayName: name,
        displayNameOriginal: name, isDiscoverable: false,
      }),
      write(`names_v2/${name}`, { code }),
    ], user.idToken);
  }
  await register(alice, aliceCode, 'finalizer-alice');
  await register(bob, bobCode, 'finalizer-bob');
  await commit([write('interests_v2/request', {
    fromCode: aliceCode, toCode: bobCode, status: 'pending',
  })], alice.idToken);
  await commit([
    write('interests_v2/request', {
      fromCode: aliceCode, toCode: bobCode, status: 'accepted', sessionId: 'restore-test',
    }),
    write(room, { requestId: 'request', participants: [aliceCode, bobCode] }),
  ], bob.idToken);
  const envelope = {
    version: 1, ephemeralPublicKey: Buffer.alloc(32, 1).toString('base64'),
    nonce, ciphertext: Buffer.alloc(48, 1).toString('base64'),
  };
  // Real key setup publishes each participant's immutable identity key first.
  for (const [user, code, name] of [
    [alice, aliceCode, 'finalizer-alice'], [bob, bobCode, 'finalizer-bob'],
  ]) {
    const publicKey = Buffer.alloc(32, name.length).toString('base64');
    await commit([
      write(`profiles_v2/${code}`, {
        uid: user.localId, code, displayName: name,
        displayNameOriginal: name, isDiscoverable: false, publicKey,
      }),
      write(`private_v2/${user.localId}/data/identity`, { publicKey }),
    ], user.idToken);
  }
  await commit([
    write(`${room}/keys/${aliceCode}`, envelope),
    write(`${room}/keys/${bobCode}`, envelope),
  ], alice.idToken);
  const uploading = { ...approved, status: 'uploading', reviewVersion: 0, decisionVersion: 0 };
  await commit([write(state, uploading)], alice.idToken);
  const staged = [write(`${state}/metadata/000000`, metadata)];
  for (let i = 0; i < 105; i++) {
    const id = `post-${String(i).padStart(3, '0')}`;
    staged.push(write(`${state}/posts/${id}`, postData(i)));
  }
  await commit(staged, alice.idToken);
  await commit([write(state, { ...uploading, status: 'verifying', reviewVersion: 1 })], alice.idToken);
  await commit([write(state, { ...uploading, status: 'review', reviewVersion: 1 })], alice.idToken);
  await commit([write(state, approved)], bob.idToken);
  const published = [write(`${room}/story_metadata/000000`, metadata)];
  for (let i = 0; i < 104; i++) {
    published.push(write(`${room}/posts/post-${String(i).padStart(3, '0')}`, postData(i)));
  }
  for (let i = 0; i < published.length; i += 10) {
    await commit(published.slice(i, i + 10), alice.idToken);
  }

  assert.equal((await finalize(null)).status, 401);
  assert.equal((await finalize(anonymous.data.idToken)).status, 401);
  assert.equal((await finalize(bob.idToken)).status, 400);
  assert.equal((await finalize(alice.idToken, 2)).status, 400);
  assert.equal((await finalize(alice.idToken)).status, 400);
  const direct = await post(`${firestore}:commit`, {
    writes: [write(state, { ...approved, status: 'completed' })],
  }, alice.idToken);
  assert.equal(direct.status, 403, JSON.stringify(direct.data));

  await commit([write(`${room}/posts/post-104`, postData(104))], alice.idToken);
  await commit([write(state, { ...approved, postCount: 106 })]);
  assert.equal((await finalize(alice.idToken)).status, 400);
  await commit([write(state, approved)]);
  await commit([write(`${room}/posts/extra`, { content: 'unexpected' })]);
  assert.equal((await finalize(alice.idToken)).status, 400);
  await commit([{ delete: `${database}/${room}/posts/extra` }]);
  await commit([write(`${room}/posts/post-104`, { content: 'wrong' })]);
  assert.equal((await finalize(alice.idToken)).status, 400);
  await commit([write(`${room}/posts/post-104`, postData(104))]);
  await commit([write(`${room}/story_metadata/000000`, { ...metadata, cipher: cipher(1) })]);
  assert.equal((await finalize(alice.idToken)).status, 400);
  const stillApproved = await fetch(`${firestore}/${state}`, {
    headers: { Authorization: 'Bearer owner' },
  });
  assert.equal((await stillApproved.json()).fields.status.stringValue, 'approved');
  await commit([write(`${room}/story_metadata/000000`, metadata)]);

  const results = await Promise.all([finalize(alice.idToken), finalize(alice.idToken)]);
  for (const result of results) {
    assert.equal(result.status, 200, JSON.stringify(result.data));
    assert.equal(result.data.result.status, 'completed');
  }
  assert.equal((await finalize(alice.idToken)).status, 200);
});
