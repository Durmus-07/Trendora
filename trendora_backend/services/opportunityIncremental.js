'use strict';

const crypto = require('crypto');

function clean(value) {
  return String(value ?? '').replace(/\s+/g, ' ').trim();
}

function normalized(value) {
  return clean(value).toLocaleLowerCase('tr-TR');
}

function stableHash(value) {
  return crypto.createHash('sha1').update(String(value ?? '')).digest('hex');
}

function opportunityIdentity(item) {
  const source = normalized(item.source || item.store);
  const externalId = clean(item.externalId || item.external_id);
  if (externalId) return `${source}|external:${externalId}`;

  const url = clean(item.officialUrl || item.url).replace(/[?#].*$/, '');
  return `${source}|${url}|${normalized(item.title)}`;
}

function opportunityHash(item) {
  return stableHash([
    normalized(item.source || item.store),
    clean(item.externalId || item.external_id),
    normalized(item.title),
    Number(item.currentPrice ?? item.price ?? 0),
    Number(item.oldPrice ?? 0),
    Number(item.discountRate ?? item.discountPercent ?? 0),
    clean(item.currency || 'TRY'),
    clean(item.officialUrl || item.url).replace(/[?#].*$/, ''),
    clean(item.imageUrl || item.image),
    clean(item.catalogStartDate),
    clean(item.catalogEndDate)
  ].join('|'));
}

function snapshotSignature(items) {
  return stableHash(items.map(item =>
    `${opportunityIdentity(item)}:${opportunityHash(item)}`
  ).sort().join('\n'));
}

function classifySourceBatch(previousItems, currentItems, now = new Date().toISOString()) {
  const previousByIdentity = new Map(
    previousItems.map(item => [opportunityIdentity(item), item])
  );
  const currentIdentities = new Set();
  const items = [];
  let newProducts = 0;
  let changedProducts = 0;
  let unchangedProducts = 0;

  for (const current of currentItems) {
    const identity = opportunityIdentity(current);
    if (!identity || currentIdentities.has(identity)) continue;
    currentIdentities.add(identity);
    const previous = previousByIdentity.get(identity);

    if (!previous) {
      newProducts += 1;
      items.push(current);
      continue;
    }

    if (opportunityHash(previous) === opportunityHash(current)) {
      unchangedProducts += 1;
      items.push(previous);
      continue;
    }

    changedProducts += 1;
    const priceChanged = Number(previous.currentPrice) !== Number(current.currentPrice);
    const statusChanged = previous.active !== current.active ||
      clean(previous.status) !== clean(current.status);
    items.push({
      ...previous,
      ...current,
      id: previous.id || current.id,
      ...(priceChanged ? {
        previousPrice: previous.currentPrice ?? null,
        previousDiscountPercent: previous.discountRate ?? previous.discountPercent ?? null,
        priceChangedAt: now
      } : {}),
      ...(statusChanged ? { statusChangedAt: now } : {})
    });
  }

  return {
    items,
    newProducts,
    changedProducts,
    unchangedProducts,
    reusedProducts: unchangedProducts,
    removedProducts: [...previousByIdentity.keys()]
      .filter(identity => !currentIdentities.has(identity)).length
  };
}

function sourceOf(item) {
  return normalized(item.store || item.source)
    .replace('bi̇m', 'bim')
    .replace('şok', 'sok');
}

module.exports = {
  classifySourceBatch,
  opportunityHash,
  opportunityIdentity,
  snapshotSignature,
  sourceOf,
  stableHash
};
