const {
  fetchMarketData
} = require('../marketDataService');

function buildClassification(prediction) {
  const symbol = String(
    prediction?.asset?.symbol || ''
  ).trim();

  const name = String(
    prediction?.asset?.name || symbol
  ).trim();

  if (!symbol && !name) {
    return null;
  }

  return {
    domain: 'finance',
    entity: {
      name: name || symbol,
      symbol: symbol || null,
      subtype: prediction?.asset?.subtype || null
    }
  };
}

async function resolvePredictionFinalPrice(
  prediction,
  options = {}
) {
  const classification = buildClassification(prediction);

  if (!classification) {
    return null;
  }

  const query =
    prediction?.query ||
    classification.entity.symbol ||
    classification.entity.name;

  const marketData = await fetchMarketData(
    query,
    classification,
    {
      forceRefresh: options.forceRefresh !== false
    }
  );

  const currentPrice = Number(
    marketData?.dailyPrice?.current
  );

  if (!Number.isFinite(currentPrice) || currentPrice <= 0) {
    return null;
  }

  return currentPrice;
}

module.exports = {
  resolvePredictionFinalPrice
};