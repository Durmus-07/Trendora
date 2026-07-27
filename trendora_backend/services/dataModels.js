'use strict';

function iso(value, fallback = null) {
  if (value == null || value === '') return fallback;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? fallback : date.toISOString();
}

function first(...values) {
  return values.find(value => value != null && String(value).trim() !== '');
}

function sourceMetadata(item, fallbackSource, fallbackUpdatedAt) {
  const source = String(first(item.source, item.sourceName, item.feedSource, item.publisher, item.store, fallbackSource, 'unknown'));
  const dataTime = iso(first(item.dataTime, item.updatedAt, item.publishedAt, item.collectedAt, fallbackUpdatedAt));
  return {
    source,
    dataTime,
    sourceInfo: {
      name: source,
      updatedAt: dataTime,
      fetchedAt: iso(first(item.fetchedAt, item.collectedAt, fallbackUpdatedAt), dataTime)
    }
  };
}

function normalizeNews(item, context = {}) {
  const metadata = sourceMetadata(item, context.source, context.updatedAt);
  return {
    ...item,
    category: first(item.category, 'genel'),
    source: metadata.source,
    relatedCompany: first(item.relatedCompany, item.company, null),
    similarNews: Array.isArray(item.similarNews) ? item.similarNews : [],
    inAppReadable: item.inAppReadable !== false && Boolean(first(item.description, item.content, item.summary)),
    ...metadata
  };
}

function normalizeOpportunity(item, context = {}) {
  const metadata = sourceMetadata(item, context.source, context.updatedAt);
  return {
    ...item,
    store: first(item.store, item.seller, metadata.source),
    category: first(item.category, 'genel'),
    price: item.price ?? item.currentPrice ?? null,
    campaignStartAt: iso(first(item.campaignStartAt, item.catalogStartDate, item.startDate)),
    campaignEndAt: iso(first(item.campaignEndAt, item.catalogEndDate, item.endDate)),
    active: item.active !== false,
    ...metadata
  };
}

function normalizeFinancial(item, context = {}) {
  const metadata = sourceMetadata(item, context.source || 'Yahoo Finance', context.updatedAt);
  return {
    ...item,
    symbol: first(item.symbol, item.code, ''),
    price: item.price ?? item.currentPrice ?? item.dailyPrice?.current ?? null,
    change: item.change ?? item.changePercent ?? item.dailyPrice?.changePercent ?? null,
    volume: item.volume ?? item.dailyPrice?.volume ?? null,
    ...metadata
  };
}

function normalizeWeather(payload, context = {}) {
  return {
    ...payload,
    ...sourceMetadata(payload, context.source || 'Open-Meteo', context.updatedAt || new Date().toISOString())
  };
}

module.exports = { normalizeNews, normalizeOpportunity, normalizeFinancial, normalizeWeather, sourceMetadata };
