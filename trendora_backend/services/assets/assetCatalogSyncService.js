'use strict';

const fs = require('fs');
const path = require('path');
const axios = require('axios');

const { ASSET_CATALOG } = require('./assetCatalog');

const KAP_BIST_URL = 'https://kap.org.tr/tr/bist-sirketler';
const FON_HAREKETLERI_URL = 'https://fonhareketleri.com/api/funds/';
const DEFAULT_REPORT_PATH = path.join(__dirname, '..', '..', 'database', 'asset-catalog-sync-latest.json');
const DAY_MS = 24 * 60 * 60 * 1000;

let schedulerStarted = false;
let schedulerTimer = null;

function normalizeText(value) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeComparable(value) {
  return normalizeText(value)
    .toLocaleUpperCase('tr-TR')
    .replace(/İ/g, 'I');
}

function envEnabled(name, defaultValue = false) {
  const raw = process.env[name];
  if (raw == null || String(raw).trim() === '') return defaultValue;
  return ['1', 'true', 'yes', 'on'].includes(String(raw).trim().toLowerCase());
}

function getCatalogSnapshot(catalog = ASSET_CATALOG) {
  const equities = catalog.filter(asset => asset.assetType === 'equity' && asset.exchange === 'BIST');
  const tefasFunds = catalog.filter(asset => asset.assetType === 'fund' && asset.market === 'TEFAS');

  return {
    catalog,
    equities,
    tefasFunds,
    byCanonicalSymbol: new Map(catalog.map(asset => [asset.canonicalSymbol, asset])),
    byInternalAssetId: new Map(catalog.map(asset => [asset.internalAssetId, asset])),
    equityBySymbol: new Map(equities.map(asset => [asset.canonicalSymbol, asset])),
    tefasByCode: new Map(tefasFunds.map(asset => [asset.canonicalSymbol, asset]))
  };
}

function parseKapBistCompanies(html) {
  const rows = [];
  const rowPattern = /<tr[\s\S]*?<\/tr>/gi;
  const cellPattern = /<td[\s\S]*?>([\s\S]*?)<\/td>/gi;
  let rowMatch;

  while ((rowMatch = rowPattern.exec(String(html || ''))) !== null) {
    const cells = [];
    let cellMatch;
    while ((cellMatch = cellPattern.exec(rowMatch[0])) !== null) {
      cells.push(cellMatch[1].replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' '));
    }
    if (cells.length < 2) continue;

    const symbol = normalizeText(cells[0]).split(' ')[0].toUpperCase();
    const name = normalizeText(cells[1]);
    if (/^[A-Z0-9]{4,6}$/.test(symbol) && name) {
      rows.push({ symbol, name });
    }
  }

  return dedupeBy(rows, item => item.symbol).sort((left, right) => left.symbol.localeCompare(right.symbol, 'tr'));
}

async function fetchBistSource() {
  const response = await axios.get(KAP_BIST_URL, {
    timeout: 20000,
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; Trendora/1.0)',
      'Accept-Language': 'tr-TR,tr;q=0.9',
      Accept: 'text/html,application/xhtml+xml'
    }
  });
  return parseKapBistCompanies(response.data);
}

async function fetchTefasSource() {
  const rows = [];
  let nextUrl = `${FON_HAREKETLERI_URL}?limit=100&page=1`;
  let pageCount = 0;

  while (nextUrl && pageCount < 100) {
    const response = await axios.get(nextUrl, {
      timeout: 20000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Trendora/1.0)',
        Accept: 'application/json'
      }
    });
    const body = response.data || {};
    rows.push(...(Array.isArray(body.results) ? body.results : []));
    nextUrl = body.next || null;
    pageCount += 1;
  }

  return rows
    .filter(item => String(item.tefas_tradability || '') === "TEFAS'ta işlem görüyor")
    .map(item => ({
      code: String(item.code || '').trim().toUpperCase(),
      name: normalizeText(item.name),
      category: normalizeText(item.category)
    }))
    .filter(item => /^[A-Z0-9]{3,6}$/.test(item.code) && item.name)
    .sort((left, right) => left.code.localeCompare(right.code, 'tr'));
}

function dedupeBy(items, keyFn) {
  const map = new Map();
  for (const item of items || []) {
    const key = keyFn(item);
    if (key && !map.has(key)) map.set(key, item);
  }
  return [...map.values()];
}

function safeBistAliases(symbol, name) {
  return [symbol, `${symbol}.IS`, `${symbol} hissesi`, name].filter(Boolean);
}

function safeTefasAliases(code, name) {
  return [code, `${code} fonu`, name].filter(Boolean);
}

function buildBistSuggestion(item) {
  return {
    internalAssetId: `bist:equity:${item.symbol}`,
    canonicalSymbol: item.symbol,
    displayName: item.name,
    assetType: 'equity',
    exchange: 'BIST',
    market: 'BIST',
    currency: 'TRY',
    providerSymbols: { yahoo: `${item.symbol}.IS` },
    aliases: safeBistAliases(item.symbol, item.name)
  };
}

function buildTefasSuggestion(item) {
  return {
    internalAssetId: `tefas:fund:${item.code}`,
    canonicalSymbol: item.code,
    displayName: item.name,
    assetType: 'fund',
    exchange: 'TEFAS',
    market: 'TEFAS',
    currency: null,
    providerSymbols: { yahoo: null },
    aliases: safeTefasAliases(item.code, item.name)
  };
}

function compareBist(sourceRows, snapshot) {
  const source = dedupeBy(sourceRows, item => String(item.symbol || '').trim().toUpperCase())
    .filter(item => /^[A-Z0-9]{4,6}$/.test(item.symbol || '') && item.name);

  const result = {
    sourceCount: source.length,
    catalogCount: snapshot.equities.length,
    added: [],
    missingFromSource: [],
    metadataChanged: [],
    conflicts: [],
    valid: source.length > 0
  };

  if (!result.valid) return result;

  const sourceBySymbol = new Map(source.map(item => [item.symbol, item]));

  for (const item of source) {
    const existing = snapshot.equityBySymbol.get(item.symbol);
    const globalExisting = snapshot.byCanonicalSymbol.get(item.symbol);

    if (!existing && globalExisting) {
      result.conflicts.push({ symbol: item.symbol, assetType: globalExisting.assetType, internalAssetId: globalExisting.internalAssetId });
      continue;
    }
    if (!existing) {
      const suggestion = buildBistSuggestion(item);
      if (snapshot.byInternalAssetId.has(suggestion.internalAssetId)) {
        result.conflicts.push({ symbol: item.symbol, internalAssetId: suggestion.internalAssetId });
      } else {
        result.added.push(suggestion);
      }
      continue;
    }
    if (normalizeComparable(existing.displayName) !== normalizeComparable(item.name)) {
      result.metadataChanged.push({
        canonicalSymbol: item.symbol,
        catalogName: existing.displayName,
        sourceName: item.name
      });
    }
  }

  for (const asset of snapshot.equities) {
    if (!sourceBySymbol.has(asset.canonicalSymbol)) {
      result.missingFromSource.push({
        canonicalSymbol: asset.canonicalSymbol,
        displayName: asset.displayName,
        internalAssetId: asset.internalAssetId
      });
    }
  }

  return result;
}

function compareTefas(sourceRows, snapshot) {
  const source = dedupeBy(sourceRows, item => String(item.code || '').trim().toUpperCase())
    .filter(item => /^[A-Z0-9]{3,6}$/.test(item.code || '') && item.name);

  const result = {
    sourceCount: source.length,
    catalogCount: snapshot.tefasFunds.length,
    added: [],
    missingFromSource: [],
    metadataChanged: [],
    conflicts: [],
    valid: source.length > 0
  };

  if (!result.valid) return result;

  const sourceByCode = new Map(source.map(item => [item.code, item]));

  for (const item of source) {
    const existing = snapshot.tefasByCode.get(item.code);
    const globalExisting = snapshot.byCanonicalSymbol.get(item.code);

    if (!existing && globalExisting) {
      result.conflicts.push({ code: item.code, assetType: globalExisting.assetType, internalAssetId: globalExisting.internalAssetId });
      continue;
    }
    if (!existing) {
      const suggestion = buildTefasSuggestion(item);
      if (snapshot.byInternalAssetId.has(suggestion.internalAssetId)) {
        result.conflicts.push({ code: item.code, internalAssetId: suggestion.internalAssetId });
      } else {
        result.added.push(suggestion);
      }
      continue;
    }
    if (normalizeComparable(existing.displayName) !== normalizeComparable(item.name)) {
      result.metadataChanged.push({
        canonicalSymbol: item.code,
        catalogName: existing.displayName,
        sourceName: item.name
      });
    }
  }

  for (const asset of snapshot.tefasFunds) {
    if (!sourceByCode.has(asset.canonicalSymbol)) {
      result.missingFromSource.push({
        canonicalSymbol: asset.canonicalSymbol,
        displayName: asset.displayName,
        internalAssetId: asset.internalAssetId
      });
    }
  }

  return result;
}

function summarizeChanged(section) {
  return Boolean(
    section.added.length ||
    section.missingFromSource.length ||
    section.metadataChanged.length ||
    section.conflicts.length
  );
}

function writeJsonAtomic(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const tempPath = `${filePath}.tmp`;
  fs.writeFileSync(tempPath, JSON.stringify(value, null, 2), 'utf8');
  fs.renameSync(tempPath, filePath);
}

function buildSummaryLog(result) {
  return [
    `[AssetCatalogSync] status=${result.status}`,
    `mode=${result.mode}`,
    `bist source=${result.bist.sourceCount} catalog=${result.bist.catalogCount} added=${result.bist.added.length}`,
    `tefas source=${result.tefas.sourceCount} catalog=${result.tefas.catalogCount} added=${result.tefas.added.length}`,
    `changed=${result.changed}`,
    `errors=${result.errors.length}`,
    `durationMs=${result.durationMs}`
  ].join(' ');
}

async function runAssetCatalogSync(options = {}) {
  const startedAt = new Date();
  const mode = String(options.mode || process.env.ASSET_CATALOG_SYNC_MODE || 'dry-run').toLowerCase();
  const snapshot = getCatalogSnapshot(options.catalog || ASSET_CATALOG);
  const errors = [];

  const result = {
    startedAt: startedAt.toISOString(),
    completedAt: null,
    durationMs: null,
    mode,
    status: 'running',
    sources: {
      bist: KAP_BIST_URL,
      tefas: FON_HAREKETLERI_URL
    },
    bist: null,
    tefas: null,
    changed: false,
    applySupported: false,
    reportPath: null,
    errors
  };

  try {
    const [bistSource, tefasSource] = await Promise.allSettled([
      (options.fetchBistSource || fetchBistSource)(),
      (options.fetchTefasSource || fetchTefasSource)()
    ]);

    if (bistSource.status === 'fulfilled') {
      result.bist = compareBist(bistSource.value, snapshot);
      if (!result.bist.valid) errors.push({ source: 'bist', message: 'BIST kaynağı boş veya geçersiz döndü.' });
    } else {
      result.bist = compareBist([], snapshot);
      errors.push({ source: 'bist', message: bistSource.reason?.message || String(bistSource.reason) });
    }

    if (tefasSource.status === 'fulfilled') {
      result.tefas = compareTefas(tefasSource.value, snapshot);
      if (!result.tefas.valid) errors.push({ source: 'tefas', message: 'TEFAS kaynağı boş veya geçersiz döndü.' });
    } else {
      result.tefas = compareTefas([], snapshot);
      errors.push({ source: 'tefas', message: tefasSource.reason?.message || String(tefasSource.reason) });
    }

    result.changed = summarizeChanged(result.bist) || summarizeChanged(result.tefas);
    result.status = errors.length ? 'degraded' : 'success';

    if (mode === 'apply') {
      result.status = errors.length ? 'degraded' : 'unsupported';
      result.errors.push({
        source: 'apply',
        message: 'APPLY modu statik assetCatalog.js dosyasını otomatik değiştirmez; sonuç yalnızca rapor olarak yazılır.'
      });
    }

  } catch (error) {
    result.status = 'failed';
    errors.push({ source: 'sync', message: error.message });
  } finally {
    const completedAt = new Date();
    result.completedAt = completedAt.toISOString();
    result.durationMs = completedAt.getTime() - startedAt.getTime();
    if (options.writeReport || mode === 'apply') {
      const reportPath = options.reportPath || DEFAULT_REPORT_PATH;
      writeJsonAtomic(reportPath, result);
      result.reportPath = reportPath;
    }
    if (options.logger !== false) {
      const logger = options.logger || console;
      logger.log(buildSummaryLog(result));
    }
  }

  return result;
}

function msUntilNextTurkeyHour(hour) {
  const now = new Date();
  const turkeyNow = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Istanbul' }));
  const nextTurkey = new Date(turkeyNow);
  nextTurkey.setHours(hour, 0, 0, 0);
  if (nextTurkey <= turkeyNow) nextTurkey.setTime(nextTurkey.getTime() + DAY_MS);
  return nextTurkey.getTime() - turkeyNow.getTime();
}

function startAssetCatalogSyncScheduler(options = {}) {
  if (schedulerStarted) {
    return { started: false, reason: 'already_started' };
  }

  const enabled = options.enabled ?? envEnabled('ASSET_CATALOG_SYNC_ENABLED', false);
  if (!enabled) {
    return { started: false, reason: 'disabled' };
  }

  schedulerStarted = true;
  const logger = options.logger === false ? null : options.logger || console;
  const scheduleHour = Number.isInteger(options.scheduleHour) ? options.scheduleHour : 3;

  async function tick() {
    try {
      await runAssetCatalogSync({
        mode: options.mode || process.env.ASSET_CATALOG_SYNC_MODE || 'dry-run',
        writeReport: options.writeReport ?? true,
        logger
      });
    } catch (error) {
      if (logger) logger.error('[AssetCatalogSync] zamanlayıcı hatası:', error?.stack || error);
    } finally {
      schedulerTimer = setTimeout(tick, DAY_MS);
      if (typeof schedulerTimer.unref === 'function') schedulerTimer.unref();
    }
  }

  schedulerTimer = setTimeout(tick, options.initialDelayMs ?? msUntilNextTurkeyHour(scheduleHour));
  if (typeof schedulerTimer.unref === 'function') schedulerTimer.unref();
  if (logger) logger.log(`[AssetCatalogSync] zamanlayıcı aktif. Hedef saat: Europe/Istanbul ${String(scheduleHour).padStart(2, '0')}:00`);

  return { started: true, reason: 'started' };
}

function stopAssetCatalogSyncScheduler() {
  if (schedulerTimer) clearTimeout(schedulerTimer);
  schedulerTimer = null;
  schedulerStarted = false;
}

module.exports = {
  runAssetCatalogSync,
  startAssetCatalogSyncScheduler,
  stopAssetCatalogSyncScheduler,
  compareBist,
  compareTefas,
  parseKapBistCompanies,
  fetchBistSource,
  fetchTefasSource,
  getCatalogSnapshot,
  DEFAULT_REPORT_PATH
};
