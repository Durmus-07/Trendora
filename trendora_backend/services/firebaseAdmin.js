let firebaseAuth;

function getFirebaseAuth() {
  if (firebaseAuth) return firebaseAuth;

  const { applicationDefault, getApps, initializeApp } = require('firebase-admin/app');
  const { getAuth } = require('firebase-admin/auth');
  const app = getApps()[0] || initializeApp({ credential: applicationDefault() });
  firebaseAuth = getAuth(app);
  return firebaseAuth;
}

async function verifyFirebaseIdToken(token) {
  return getFirebaseAuth().verifyIdToken(token);
}

module.exports = {
  verifyFirebaseIdToken
};
