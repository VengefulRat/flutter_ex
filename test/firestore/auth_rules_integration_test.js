// From this directory: firebase emulators:exec --project demo-lore-migration
// --only auth,firestore --config firebase.json "node --test auth_rules_integration_test.js"
const assert = require('node:assert/strict');
const { test } = require('node:test');

const project = 'demo-lore-migration';
const authBase = 'http://127.0.0.1:18765/identitytoolkit.googleapis.com/v1';
const database = `projects/${project}/databases/(default)/documents`;
const firestoreBase = `http://127.0.0.1:18764/v1/${database}`;

async function post(url, body, token) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, data: await response.json() };
}

function document(path, data) {
  return {
    update: {
      name: `${database}/${path}`,
      fields: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [
          key,
          typeof value === 'boolean' ? { booleanValue: value } : { stringValue: value },
        ]),
      ),
    },
  };
}

test('real emulator password identities can create and access only their accounts', async () => {
  const email = 'alice@example.invalid';
  const password = 'emulator-password';
  const signup = await post(`${authBase}/accounts:signUp?key=demo-key`, {
    email,
    password,
    returnSecureToken: true,
  });
  assert.equal(signup.status, 200, JSON.stringify(signup.data));
  const uid = signup.data.localId;
  const code = 'LR-ABCD-EFGH';
  const created = await post(`${firestoreBase}:commit`, {
    writes: [
      document(`accounts_v2/${uid}`, { code }),
      document(`profiles_v2/${code}`, {
        uid,
        code,
        displayName: 'alice',
        displayNameOriginal: 'Alice',
        isDiscoverable: true,
      }),
      document('names_v2/alice', { code }),
      document(`private_v2/${uid}/diary/entry`, { text: 'private' }),
    ],
  }, signup.data.idToken);
  assert.equal(created.status, 200, JSON.stringify(created.data));

  const signin = await post(`${authBase}/accounts:signInWithPassword?key=demo-key`, {
    email,
    password,
    returnSecureToken: true,
  });
  assert.equal(signin.status, 200, JSON.stringify(signin.data));
  const ownDiary = await fetch(`${firestoreBase}/private_v2/${uid}/diary/entry`, {
    headers: { Authorization: `Bearer ${signin.data.idToken}` },
  });
  assert.equal(ownDiary.status, 200);

  const other = await post(`${authBase}/accounts:signUp?key=demo-key`, {
    email: 'bob@example.invalid',
    password,
    returnSecureToken: true,
  });
  assert.equal(other.status, 200, JSON.stringify(other.data));
  const otherRead = await fetch(`${firestoreBase}/private_v2/${uid}/diary/entry`, {
    headers: { Authorization: `Bearer ${other.data.idToken}` },
  });
  assert.equal(otherRead.status, 403);

  const reset = await post(`${authBase}/accounts:sendOobCode?key=demo-key`, {
    requestType: 'PASSWORD_RESET',
    email,
  });
  assert.equal(reset.status, 200, JSON.stringify(reset.data));
});
