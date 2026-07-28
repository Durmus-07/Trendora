const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createFirebaseAuthMiddleware,
  requirePremiumUser
} = require('../middleware/firebaseAuth');

function responseRecorder() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    }
  };
}

async function authorize({ authorization, body, verifier }) {
  const req = {
    body: body || {},
    get(name) {
      return name.toLowerCase() === 'authorization' ? authorization : undefined;
    }
  };
  const res = responseRecorder();
  let allowed = false;
  const authenticate = createFirebaseAuthMiddleware({ verifyIdToken: verifier });

  await authenticate(req, res, () => {
    requirePremiumUser(req, res, () => {
      allowed = true;
    });
  });

  return { allowed, req, res };
}

test('missing Firebase token returns 401', async () => {
  const result = await authorize({ verifier: async () => ({ uid: 'unused' }) });
  assert.equal(result.res.statusCode, 401);
  assert.equal(result.res.body.code, 'AUTH_REQUIRED');
  assert.equal(result.allowed, false);
});

test('invalid Firebase token returns 401', async () => {
  const result = await authorize({
    authorization: 'Bearer invalid-token',
    verifier: async () => { throw new Error('invalid'); }
  });
  assert.equal(result.res.statusCode, 401);
  assert.equal(result.res.body.code, 'INVALID_TOKEN');
  assert.equal(result.allowed, false);
});

test('verified user without premium claim returns 403', async () => {
  const result = await authorize({
    authorization: 'Bearer valid-token',
    verifier: async () => ({ uid: 'firebase-user' })
  });
  assert.equal(result.res.statusCode, 403);
  assert.equal(result.res.body.code, 'PREMIUM_REQUIRED');
  assert.equal(result.allowed, false);
});

test('verified premium claim grants access', async () => {
  const result = await authorize({
    authorization: 'Bearer valid-token',
    verifier: async () => ({ uid: 'firebase-user', premium: true })
  });
  assert.equal(result.res.statusCode, 200);
  assert.equal(result.allowed, true);
  assert.equal(result.req.firebaseUser.premium, true);
});

test('request body cannot forge premium access', async () => {
  const result = await authorize({
    authorization: 'Bearer valid-token',
    body: { premium: true, isPremium: true },
    verifier: async () => ({ uid: 'firebase-user', premium: false })
  });
  assert.equal(result.res.statusCode, 403);
  assert.equal(result.res.body.code, 'PREMIUM_REQUIRED');
  assert.equal(result.allowed, false);
});

test('guest identity is never accepted as Premium', async () => {
  const result = await authorize({
    authorization: 'Bearer valid-token',
    verifier: async () => ({ uid: 'guest:local-user', premium: true })
  });
  assert.equal(result.res.statusCode, 403);
  assert.equal(result.res.body.code, 'PREMIUM_REQUIRED');
  assert.equal(result.allowed, false);
});
