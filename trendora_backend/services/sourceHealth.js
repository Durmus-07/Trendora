'use strict';

const sources = new Map();

function snapshot(name) {
  return {
    name,
    status: 'unknown',
    lastSuccessAt: null,
    lastErrorAt: null,
    lastError: null,
    recordCount: 0,
    responseTimeMs: null,
    consecutiveFailures: 0,
    ...(sources.get(name) || {})
  };
}

function success(name, { recordCount = 0, responseTimeMs = null } = {}) {
  const previous = snapshot(name);
  sources.set(name, {
    ...previous,
    status: 'healthy',
    lastSuccessAt: new Date().toISOString(),
    lastError: null,
    recordCount: Number(recordCount) || 0,
    responseTimeMs: Number.isFinite(Number(responseTimeMs)) ? Number(responseTimeMs) : null,
    consecutiveFailures: 0
  });
}

function failure(name, error, { responseTimeMs = null } = {}) {
  const previous = snapshot(name);
  sources.set(name, {
    ...previous,
    status: 'degraded',
    lastErrorAt: new Date().toISOString(),
    lastError: String(error?.message || error || 'Unknown error').slice(0, 500),
    responseTimeMs: Number.isFinite(Number(responseTimeMs)) ? Number(responseTimeMs) : null,
    consecutiveFailures: previous.consecutiveFailures + 1
  });
}

async function track(name, operation, count = value => Array.isArray(value) ? value.length : 0) {
  const startedAt = Date.now();
  try {
    const value = await operation();
    success(name, { recordCount: count(value), responseTimeMs: Date.now() - startedAt });
    return value;
  } catch (error) {
    failure(name, error, { responseTimeMs: Date.now() - startedAt });
    throw error;
  }
}

function getAll() {
  return [...sources.keys()].sort().map(snapshot);
}

module.exports = { success, failure, track, snapshot, getAll };
