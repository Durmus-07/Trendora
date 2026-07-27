'use strict';

const cache = new Map();
const inFlight = new Map();

const wait = ms => new Promise(resolve => setTimeout(resolve, ms));

async function resilientRequest(key, operation, options = {}) {
  const ttlMs = Math.max(0, Number(options.ttlMs || 0));
  const retries = Math.min(3, Math.max(0, Number(options.retries ?? 1)));
  const cached = cache.get(key);
  if (!options.forceRefresh && cached && Date.now() - cached.createdAt < ttlMs) return cached.value;
  if (inFlight.has(key)) return inFlight.get(key);

  const request = (async () => {
    let lastError;
    for (let attempt = 0; attempt <= retries; attempt += 1) {
      try {
        const value = await operation(attempt);
        cache.set(key, { createdAt: Date.now(), value });
        return value;
      } catch (error) {
        lastError = error;
        if (attempt < retries) await wait(Math.min(2000, 250 * (2 ** attempt) + Math.floor(Math.random() * 150)));
      }
    }
    if (options.staleIfError !== false && cached) return cached.value;
    throw lastError;
  })();

  inFlight.set(key, request);
  try { return await request; } finally { inFlight.delete(key); }
}

module.exports = { resilientRequest };
