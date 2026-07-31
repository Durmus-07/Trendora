'use strict';

const { ASSET_CATALOG } = require('./assetCatalog');

const TURKISH_CHAR_MAP = {
  ç: 'c', Ç: 'c',
  ğ: 'g', Ğ: 'g',
  ı: 'i', I: 'i',
  İ: 'i', i: 'i',
  ö: 'o', Ö: 'o',
  ş: 's', Ş: 's',
  ü: 'u', Ü: 'u'
};

function normalizeAssetQuery(input) {
  const original = String(input || '').trim();
  const withoutProviderSuffix = original.replace(/\.IS\b/gi, '');
  const ascii = withoutProviderSuffix
    .replace(/[çÇğĞıIİiöÖşŞüÜ]/g, character => TURKISH_CHAR_MAP[character] || character)
    .toLowerCase();
  const normalized = ascii
    .replace(/&/g, ' ')
    .replace(/[’'`]/g, '')
    .replace(/[^a-z0-9./\-\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const compact = normalized.replace(/[^a-z0-9]/g, '');
  const ticker = original
    .toLocaleUpperCase('tr-TR')
    .replace(/İ/g, 'I')
    .replace(/[^A-Z0-9.]/g, '')
    .trim();

  return {
    original,
    normalized,
    compact,
    ticker,
    providerSuffixRemoved: withoutProviderSuffix.trim()
  };
}

function normalizeCatalogText(value) {
  return normalizeAssetQuery(value).normalized;
}

function compactCatalogText(value) {
  return normalizeAssetQuery(value).compact;
}

function assetView(asset) {
  if (!asset) return null;
  return {
    internalAssetId: asset.internalAssetId,
    canonicalSymbol: asset.canonicalSymbol,
    displayName: asset.displayName,
    assetType: asset.assetType,
    exchange: asset.exchange,
    market: asset.market,
    currency: asset.currency,
    providerSymbols: { ...(asset.providerSymbols || {}) }
  };
}

function candidateView(asset, matchType, confidence, matchedValue) {
  return {
    matchType,
    confidence,
    matchedValue,
    asset: assetView(asset)
  };
}

function resultFrom(asset, matchType, confidence, candidates = []) {
  return {
    matched: true,
    matchType,
    confidence,
    asset: assetView(asset),
    candidates
  };
}

function emptyResult(matchType = 'none', candidates = []) {
  return {
    matched: false,
    matchType,
    confidence: 0,
    asset: null,
    candidates
  };
}

const index = buildIndex();

function addUnique(map, key, candidate) {
  if (!key) return;
  const existing = map.get(key) || [];
  if (!existing.some(item => item.asset.internalAssetId === candidate.asset.internalAssetId)) {
    existing.push(candidate);
  }
  map.set(key, existing);
}

function buildIndex() {
  const byInternalId = new Map();
  const byCanonicalSymbol = new Map();
  const byProviderSymbol = new Map();
  const byName = new Map();
  const byAlias = new Map();
  const fuzzyTerms = [];

  for (const asset of ASSET_CATALOG) {
    byInternalId.set(String(asset.internalAssetId).toLowerCase(), asset);
    byCanonicalSymbol.set(String(asset.canonicalSymbol).toUpperCase(), asset);
    addUnique(byName, normalizeCatalogText(asset.displayName), {
      asset,
      matchType: 'exact_name',
      matchedValue: asset.displayName
    });
    addUnique(byName, normalizeCatalogText(asset.normalizedName), {
      asset,
      matchType: 'exact_name',
      matchedValue: asset.normalizedName
    });

    for (const providerSymbol of Object.values(asset.providerSymbols || {})) {
      if (!providerSymbol) continue;
      byProviderSymbol.set(String(providerSymbol).toUpperCase(), asset);
    }

    for (const alias of [...(asset.aliases || []), ...(asset.searchTerms || [])]) {
      addUnique(byAlias, normalizeCatalogText(alias), {
        asset,
        matchType: 'exact_alias',
        matchedValue: alias
      });
      addUnique(byAlias, compactCatalogText(alias), {
        asset,
        matchType: 'exact_alias',
        matchedValue: alias
      });
    }

    const terms = [
      asset.canonicalSymbol,
      asset.displayName,
      asset.normalizedName,
      ...(asset.aliases || []),
      ...(asset.searchTerms || [])
    ];
    for (const term of terms) {
      const normalized = normalizeCatalogText(term);
      if (normalized.length >= 4) {
        fuzzyTerms.push({ asset, term: normalized });
      }
    }
  }

  return {
    byInternalId,
    byCanonicalSymbol,
    byProviderSymbol,
    byName,
    byAlias,
    fuzzyTerms
  };
}

function pickOrAmbiguous(candidates, matchType, confidence) {
  if (!candidates.length) return null;
  const unique = candidates.map(item => item.asset);
  if (unique.length === 1) return resultFrom(unique[0], matchType, confidence);
  return emptyResult(
    'ambiguous',
    candidates.map(item => candidateView(item.asset, item.matchType || matchType, confidence, item.matchedValue))
  );
}

function levenshtein(left, right) {
  if (left === right) return 0;
  if (!left) return right.length;
  if (!right) return left.length;

  const previous = Array.from({ length: right.length + 1 }, (_, index) => index);
  const current = new Array(right.length + 1);

  for (let i = 0; i < left.length; i += 1) {
    current[0] = i + 1;
    for (let j = 0; j < right.length; j += 1) {
      const cost = left[i] === right[j] ? 0 : 1;
      current[j + 1] = Math.min(
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost
      );
    }
    previous.splice(0, previous.length, ...current);
  }

  return previous[right.length];
}

function similarity(left, right) {
  const maxLength = Math.max(left.length, right.length);
  if (maxLength === 0) return 1;
  return 1 - levenshtein(left, right) / maxLength;
}

function fuzzyCandidates(normalized) {
  if (normalized.normalized.length < 5) return [];

  const candidates = [];
  for (const item of index.fuzzyTerms) {
    const score = similarity(normalized.normalized, item.term);
    if (score >= 0.88) {
      candidates.push(candidateView(item.asset, 'fuzzy', Number(score.toFixed(3)), item.term));
    }
  }

  return candidates
    .sort((a, b) => b.confidence - a.confidence)
    .filter((item, position, list) =>
      position === list.findIndex(other =>
        other.asset.internalAssetId === item.asset.internalAssetId
      )
    )
    .slice(0, 5);
}

function findAssetCandidates(input, options = {}) {
  const normalized = normalizeAssetQuery(input);
  const candidates = [];
  const add = (asset, matchType, confidence, matchedValue) => {
    if (!asset) return;
    if (options.assetType && asset.assetType !== options.assetType) return;
    candidates.push(candidateView(asset, matchType, confidence, matchedValue));
  };

  add(index.byInternalId.get(normalized.original.toLowerCase()), 'internal_asset_id', 1, normalized.original);
  add(index.byCanonicalSymbol.get(normalized.ticker), 'canonical_symbol', 1, normalized.ticker);
  add(index.byCanonicalSymbol.get(normalized.providerSuffixRemoved.toUpperCase()), 'canonical_symbol', 1, normalized.providerSuffixRemoved);
  add(index.byProviderSymbol.get(normalized.ticker), 'provider_symbol', 1, normalized.ticker);

  for (const item of index.byName.get(normalized.normalized) || []) {
    add(item.asset, 'exact_name', 0.98, item.matchedValue);
  }
  for (const item of index.byAlias.get(normalized.normalized) || []) {
    add(item.asset, 'exact_alias', 0.96, item.matchedValue);
  }
  for (const item of index.byAlias.get(normalized.compact) || []) {
    add(item.asset, 'exact_alias', 0.96, item.matchedValue);
  }

  for (const item of fuzzyCandidates(normalized)) {
    if (!options.assetType || item.asset.assetType === options.assetType) {
      candidates.push(item);
    }
  }

  return candidates
    .filter((item, position, list) =>
      position === list.findIndex(other =>
        other.asset.internalAssetId === item.asset.internalAssetId &&
        other.matchType === item.matchType
      )
    )
    .sort((a, b) => b.confidence - a.confidence);
}

function matchAsset(input, options = {}) {
  const normalized = normalizeAssetQuery(input);
  if (!normalized.original) return emptyResult();

  const internal = index.byInternalId.get(normalized.original.toLowerCase());
  if (internal) return resultFrom(internal, 'internal_asset_id', 1);

  const canonical = index.byCanonicalSymbol.get(normalized.ticker) ||
    index.byCanonicalSymbol.get(normalized.providerSuffixRemoved.toUpperCase());
  if (canonical) return resultFrom(canonical, 'canonical_symbol', 1);

  const provider = index.byProviderSymbol.get(normalized.ticker);
  if (provider) return resultFrom(provider, 'provider_symbol', 1);

  const nameMatch = pickOrAmbiguous(index.byName.get(normalized.normalized) || [], 'exact_name', 0.98);
  if (nameMatch) return nameMatch;

  const aliasMatches = [
    ...(index.byAlias.get(normalized.normalized) || []),
    ...(index.byAlias.get(normalized.compact) || [])
  ].filter((item, position, list) =>
    position === list.findIndex(other => other.asset.internalAssetId === item.asset.internalAssetId)
  );
  const aliasMatch = pickOrAmbiguous(aliasMatches, 'exact_alias', 0.96);
  if (aliasMatch) return aliasMatch;

  const fuzzy = fuzzyCandidates(normalized);
  if (fuzzy.length === 1 && fuzzy[0].confidence >= 0.92) {
    return resultFrom(fuzzy[0].asset, 'fuzzy', fuzzy[0].confidence);
  }
  if (fuzzy.length > 1 && fuzzy[0].confidence - fuzzy[1].confidence < 0.05) {
    return emptyResult('ambiguous', fuzzy);
  }

  return emptyResult();
}

module.exports = {
  normalizeAssetQuery,
  matchAsset,
  findAssetCandidates
};
