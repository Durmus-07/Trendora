async function defaultTokenVerifier(token) {
  const { verifyFirebaseIdToken } = require('../services/firebaseAdmin');
  return verifyFirebaseIdToken(token);
}

function readBearerToken(req) {
  const authorization = String(req.get('authorization') || '').trim();
  const match = authorization.match(/^Bearer\s+([^\s]+)$/i);
  return match ? match[1] : null;
}

function createFirebaseAuthMiddleware({ verifyIdToken = defaultTokenVerifier } = {}) {
  return async function requireFirebaseUser(req, res, next) {
    const token = readBearerToken(req);
    if (!token) {
      return res.status(401).json({
        success: false,
        code: 'AUTH_REQUIRED',
        message: 'Geçerli bir oturum gerekli.'
      });
    }

    try {
      const decoded = await verifyIdToken(token);
      const uid = String(decoded?.uid || decoded?.sub || '').trim();
      if (!uid) throw new Error('TOKEN_WITHOUT_UID');

      req.firebaseUser = Object.freeze({
        uid,
        premium: decoded?.premium === true
      });
      return next();
    } catch (_) {
      return res.status(401).json({
        success: false,
        code: 'INVALID_TOKEN',
        message: 'Oturum doğrulanamadı.'
      });
    }
  };
}

function requirePremiumUser(req, res, next) {
  const user = req.firebaseUser;
  const isFirebaseUser = Boolean(user?.uid) && !String(user.uid).startsWith('guest:');

  if (!isFirebaseUser || user.premium !== true) {
    return res.status(403).json({
      success: false,
      code: 'PREMIUM_REQUIRED',
      message: 'Bu işlem için Premium yetkisi gerekli.'
    });
  }

  return next();
}

const requireFirebaseUser = createFirebaseAuthMiddleware();

module.exports = {
  createFirebaseAuthMiddleware,
  readBearerToken,
  requireFirebaseUser,
  requirePremiumUser
};
