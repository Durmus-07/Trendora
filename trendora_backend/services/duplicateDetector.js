'use strict';

const crypto = require('crypto');

function normalize(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/https?:\/\/\S+/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function normalizeUrl(value) {
  try {
    const url = new URL(String(value || '').trim());
    url.hash = '';
    return url.toString().replace(/\/$/, '');
  } catch {
    return '';
  }
}

function fingerprint(item, type = 'generic') {
  if (type === 'opportunity') {
    const stableId = normalize(item.id);
    if (stableId) return `id:${stableId}`;

    const stableUrl = normalizeUrl(item.officialUrl || item.url);
    if (stableUrl) return `url:${stableUrl}`;
  }

  const parts = type === 'opportunity'
    ? [
        item.store || item.source,
        item.title,
        item.price ?? item.currentPrice,
        String(
          item.campaignDate ||
          item.catalogStartDate ||
          item.publishedAt ||
          item.collectedAt ||
          ''
        ).slice(0, 10)
      ]
    : [
        item.title,
        item.source || item.feedSource,
        item.publishedAt && String(item.publishedAt).slice(0, 10)
      ];
  return crypto.createHash('sha256').update(normalize(parts.join('|'))).digest('hex');
}

function findDuplicates(items, type) {
  const firstByFingerprint = new Map();
  const duplicates = [];
  items.forEach((item, index) => {
    const key = fingerprint(item, type);
    if (firstByFingerprint.has(key)) {
      duplicates.push({ index, duplicateOf: firstByFingerprint.get(key), fingerprint: key });
    } else {
      firstByFingerprint.set(key, index);
    }
  });
  return duplicates;
}

function dedupe(items, type) {
  const seen = new Set();
  return items.filter(item => {
    const key = fingerprint(item, type);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

module.exports = { fingerprint, findDuplicates, dedupe };
