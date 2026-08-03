'use strict';

const fs = require('fs');
const path = require('path');
const { bimBatchGetir } = require('./bimCollector');
const { migrosUrunleriniGetir } = require('./migrosCollector');
const { carrefoursaUrunleriniGetir } = require('./carrefoursaCollector');
const { a101UrunleriniGetir } = require('./a101Collector');
const sourceHealth = require('./sourceHealth');
const { dedupe } = require('./duplicateDetector');
const {
  classifySourceBatch,
  snapshotSignature,
  sourceOf
} = require('./opportunityIncremental');

const databasePath = path.join(__dirname, '..', 'database', 'opportunities.json');
const statePath = path.join(__dirname, '..', 'database', 'market-collector-state.json');
const MINUTE = 60 * 1000;
const HEALTH_CHECK_MS = 24 * 60 * MINUTE;
const BETWEEN_MARKETS_MS = 45 * 1000;

async function collectBim(previousState = {}) {
  return bimBatchGetir(previousState);
}

const SOURCE_DEFINITIONS = Object.freeze([
  { source: 'bim', status: 'active', refreshIntervalMinutes: 60, collector: collectBim },
  { source: 'migros', status: 'active', refreshIntervalMinutes: 15, collector: migrosUrunleriniGetir },
  {
    source: 'carrefoursa', status: 'health_check_only', refreshIntervalMinutes: 60,
    healthCheckIntervalMinutes: 1440,
    disabledReason: 'HTTP 403 bot koruması', collector: carrefoursaUrunleriniGetir
  },
  {
    source: 'a101', status: 'health_check_only', refreshIntervalMinutes: 60,
    healthCheckIntervalMinutes: 1440,
    disabledReason: 'HTTP 403 bot koruması', collector: a101UrunleriniGetir
  }
]);

let started = false;
let timer = null;
let runPromise = null;

function readJson(filePath, fallback) {
  try {
    if (!fs.existsSync(filePath)) return fallback;
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return parsed && typeof parsed === 'object' ? parsed : fallback;
  } catch (error) {
    console.error(`[MarketScheduler] ${path.basename(filePath)} okunamadı:`, error.message);
    return fallback;
  }
}

function writeJsonAtomic(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const tempPath = `${filePath}.tmp`;
  fs.writeFileSync(tempPath, JSON.stringify(value, null, 2), 'utf8');
  fs.renameSync(tempPath, filePath);
}

function readDatabase() {
  const data = readJson(databasePath, { updatedAt: null, items: [] });
  return { updatedAt: data.updatedAt || null, items: Array.isArray(data.items) ? data.items : [] };
}

function readState() {
  const state = readJson(statePath, { markets: {} });
  return { ...state, markets: state.markets && typeof state.markets === 'object' ? state.markets : {} };
}

function sourceIsDue(definition, marketState, { initialRun = false, now = Date.now() } = {}) {
  if (definition.status === 'active' && initialRun) return true;
  const field = definition.status === 'health_check_only' ? 'nextHealthCheckAt' : 'nextEligibleFetchAt';
  const legacy = definition.status === 'active' ? marketState.nextRunAt : null;
  const timestamp = new Date(marketState[field] || legacy || 0).getTime();
  return !Number.isFinite(timestamp) || timestamp <= now;
}

function backoffMs(failures) {
  if (failures >= 5) return 2 * 60 * MINUTE;
  if (failures >= 3) return 30 * MINUTE;
  return 0;
}

function httpStatusOf(error) {
  return Number(error?.response?.status || error?.status || 0) || null;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function executeMarketCollectors({ initialRun = false, now = Date.now() } = {}) {
  const startedAt = Date.now();
  const database = readDatabase();
  const originalSignature = snapshotSignature(database.items);
  let workingItems = [...database.items];
  const state = readState();
  const metrics = {
    totalSources: SOURCE_DEFINITIONS.length,
    activeSources: SOURCE_DEFINITIONS.filter(item => item.status === 'active').length,
    attemptedSources: 0,
    successfulSources: 0,
    failedSources: 0,
    skippedSources: 0,
    notModifiedSources: 0,
    healthCheckSources: 0,
    newProducts: 0,
    changedProducts: 0,
    unchangedProducts: 0,
    reusedProducts: 0,
    removedProducts: 0,
    expiredProducts: 0,
    opportunitiesWritten: false
  };
  const durations = [];

  state.lastRunStartedAt = new Date(startedAt).toISOString();
  state.collectorRunning = true;

  try {
    for (const definition of SOURCE_DEFINITIONS) {
      const previousState = state.markets[definition.source] || {};
      const effectiveStatus = previousState.status || definition.status;
      const isHealthCheck = effectiveStatus === 'health_check_only';
      const effectiveDefinition = { ...definition, status: effectiveStatus };
      const schedulingDefinition = initialRun && definition.status === 'active'
        ? definition
        : effectiveDefinition;

      if (!sourceIsDue(schedulingDefinition, previousState, { initialRun, now })) {
        metrics.skippedSources += 1;
        continue;
      }

      metrics.attemptedSources += effectiveStatus === 'active' ? 1 : 0;
      metrics.healthCheckSources += isHealthCheck ? 1 : 0;
      const sourceStartedAt = Date.now();

      try {
        const result = await definition.collector(previousState);
        const durationMs = Date.now() - sourceStartedAt;
        durations.push({ source: definition.source, durationMs });
        const items = Array.isArray(result?.items) ? result.items : [];
        const checkedAt = new Date().toISOString();

        if (isHealthCheck) {
          const healthPassed = result?.changed === true && items.length > 0;
          const healthSuccesses = healthPassed
            ? Number(previousState.healthSuccesses || 0) + 1
            : 0;
          state.markets[definition.source] = {
            ...previousState,
            ...(result?.state || {}),
            status: healthSuccesses >= 2 ? 'active' : 'health_check_only',
            healthSuccesses,
            lastHealthCheckAt: checkedAt,
            lastSuccessAt: checkedAt,
            nextHealthCheckAt: new Date(Date.now() + HEALTH_CHECK_MS).toISOString(),
            consecutiveFailures: 0,
            lastHttpStatus: result?.reason === 'not-modified' ? 304 : 200,
            lastErrorType: null,
            lastDurationMs: durationMs,
            lastItemCount: items.length,
            nextEligibleFetchAt: healthSuccesses >= 2
              ? new Date(Date.now() + definition.refreshIntervalMinutes * MINUTE).toISOString()
              : null,
            disabledReason: healthSuccesses >= 2 ? null : definition.disabledReason
          };
          continue;
        }

        metrics.successfulSources += 1;
        if (result?.reason === 'not-modified' || result?.reason === 'same-hash') {
          metrics.notModifiedSources += 1;
        } else if (result?.changed && items.length > 0) {
          const previousItems = workingItems.filter(item => sourceOf(item) === definition.source);
          const classified = classifySourceBatch(previousItems, dedupe(items, 'opportunity'));
          workingItems = [
            ...workingItems.filter(item => sourceOf(item) !== definition.source),
            ...classified.items
          ];
          for (const key of ['newProducts', 'changedProducts', 'unchangedProducts', 'reusedProducts', 'removedProducts']) {
            metrics[key] += classified[key];
          }
        }

        const intervalMs = definition.refreshIntervalMinutes * MINUTE;
        state.markets[definition.source] = {
          ...previousState,
          ...(result?.state || {}),
          status: 'active',
          lastAttemptAt: checkedAt,
          lastSuccessAt: checkedAt,
          consecutiveFailures: 0,
          lastHttpStatus: 200,
          lastErrorType: null,
          lastDurationMs: durationMs,
          averageDurationMs: Math.round(previousState.averageDurationMs
            ? previousState.averageDurationMs * 0.75 + durationMs * 0.25 : durationMs),
          lastItemCount: items.length || previousState.lastItemCount || 0,
          nextEligibleFetchAt: new Date(Date.now() + intervalMs).toISOString(),
          disabledReason: null
        };
        sourceHealth.success(`market:${definition.source}`, { recordCount: items.length, responseTimeMs: durationMs });
      } catch (error) {
        const durationMs = Date.now() - sourceStartedAt;
        durations.push({ source: definition.source, durationMs });
        const statusCode = httpStatusOf(error);
        const failures = Number(previousState.consecutiveFailures || 0) + 1;
        const becomesHealthOnly = isHealthCheck || statusCode === 403;
        const failedAt = new Date().toISOString();
        const delay = becomesHealthOnly ? HEALTH_CHECK_MS :
          (backoffMs(failures) || definition.refreshIntervalMinutes * MINUTE);

        state.markets[definition.source] = {
          ...previousState,
          status: becomesHealthOnly ? 'health_check_only' : (failures >= 3 ? 'backoff' : 'active'),
          lastAttemptAt: failedAt,
          lastFailureAt: failedAt,
          lastHealthCheckAt: isHealthCheck ? failedAt : previousState.lastHealthCheckAt || null,
          consecutiveFailures: failures,
          healthSuccesses: 0,
          lastHttpStatus: statusCode,
          lastErrorType: error?.code || error?.name || 'SOURCE_ERROR',
          lastDurationMs: durationMs,
          nextEligibleFetchAt: becomesHealthOnly ? null : new Date(Date.now() + delay).toISOString(),
          nextHealthCheckAt: becomesHealthOnly ? new Date(Date.now() + HEALTH_CHECK_MS).toISOString() : null,
          disabledReason: becomesHealthOnly ? `HTTP ${statusCode || 'erişim'} engeli` : null
        };
        if (!isHealthCheck) metrics.failedSources += 1;
        sourceHealth.failure(`market:${definition.source}`, error, { responseTimeMs: durationMs });
        console.error(`[MarketScheduler] ${definition.source} hatası:`, error.message);
      }

      if (metrics.attemptedSources + metrics.healthCheckSources < SOURCE_DEFINITIONS.length) {
        await sleep(BETWEEN_MARKETS_MS);
      }
    }

    const nextSignature = snapshotSignature(workingItems);
    if (nextSignature !== originalSignature) {
      writeJsonAtomic(databasePath, { updatedAt: new Date().toISOString(), items: workingItems });
      metrics.opportunitiesWritten = true;
    }
    state.lastSuccessfulRunAt = new Date().toISOString();
    return { success: metrics.failedSources === 0, ...metrics };
  } finally {
    state.collectorRunning = false;
    state.lastRunCompletedAt = new Date().toISOString();
    state.runDurationMs = Date.now() - startedAt;
    state.sourceStatuses = SOURCE_DEFINITIONS.map(definition => ({
      source: definition.source,
      status: state.markets[definition.source]?.status || definition.status,
      ...state.markets[definition.source]
    }));
    state.metrics = metrics;
    state.slowestSources = durations.sort((a, b) => b.durationMs - a.durationMs).slice(0, 4);
    writeJsonAtomic(statePath, state);
    console.log('[MarketScheduler] Tur özeti:', { ...metrics, durationMs: state.runDurationMs, slowestSources: state.slowestSources });
  }
}

function runMarketCollectorsNow(options) {
  if (runPromise) return runPromise;
  runPromise = executeMarketCollectors(options).finally(() => { runPromise = null; });
  return runPromise;
}

function scheduleNext() {
  clearTimeout(timer);
  const state = readState();
  const timestamps = Object.values(state.markets || {}).flatMap(item =>
    [item.nextEligibleFetchAt, item.nextHealthCheckAt]
      .map(value => new Date(value || 0).getTime())
      .filter(value => Number.isFinite(value) && value > Date.now())
  );
  const delay = timestamps.length ? Math.max(MINUTE, Math.min(...timestamps) - Date.now()) : 2 * MINUTE;
  timer = setTimeout(async () => {
    try { await runMarketCollectorsNow(); }
    catch (error) { console.error('[MarketScheduler] Genel çalışma hatası:', error?.stack || error); }
    finally { scheduleNext(); }
  }, delay);
  if (typeof timer.unref === 'function') timer.unref();
}

function startMarketCollectorScheduler() {
  if (started) return;
  started = true;
  console.log('[MarketScheduler] Aktif: BİM, Migros. Sağlık kontrolü: A101, CarrefourSA.');
  timer = setTimeout(async () => {
    try { await runMarketCollectorsNow({ initialRun: true }); }
    catch (error) { console.error('[MarketScheduler] İlk çalışma hatası:', error?.stack || error); }
    finally { scheduleNext(); }
  }, 90 * 1000);
  if (typeof timer.unref === 'function') timer.unref();
}

function getMarketCollectorStatus() {
  const state = readState();
  const database = readDatabase();
  const databaseUpdatedAt = database.updatedAt || null;
  const databaseAgeMs = databaseUpdatedAt
    ? Date.now() - new Date(databaseUpdatedAt).getTime()
    : Number.POSITIVE_INFINITY;
  const latestOpportunityMs = database.items.reduce((latest, item) => {
    const timestamp = new Date(
      item.verifiedAt || item.updatedAt || item.publishedAt || item.createdAt || 0
    ).getTime();
    return Number.isFinite(timestamp) && timestamp > latest ? timestamp : latest;
  }, 0);
  const statuses = Object.fromEntries(SOURCE_DEFINITIONS.map(definition => [
    definition.source,
    state.markets[definition.source]?.status || definition.status
  ]));
  const activeMarkets = Object.keys(statuses).filter(source => statuses[source] === 'active');
  const disabledMarkets = Object.keys(statuses).filter(source => statuses[source] !== 'active');
  return {
    running: Boolean(runPromise),
    activeMarkets,
    disabledMarkets,
    totalSources: SOURCE_DEFINITIONS.length,
    activeSources: activeMarkets.length,
    databaseUpdatedAt,
    latestOpportunityAt: latestOpportunityMs
      ? new Date(latestOpportunityMs).toISOString()
      : null,
    freshnessStatus: runPromise
      ? 'running'
      : databaseAgeMs <= 60 * MINUTE
        ? 'fresh'
        : databaseAgeMs <= 6 * 60 * MINUTE
          ? 'delayed'
          : 'stale',
    ...state,
    ...(state.metrics || {})
  };
}

module.exports = {
  SOURCE_DEFINITIONS,
  backoffMs,
  getMarketCollectorStatus,
  runMarketCollectorsNow,
  sourceIsDue,
  startMarketCollectorScheduler
};
