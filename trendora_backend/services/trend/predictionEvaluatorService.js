const {
  getDuePredictions,
  updatePredictionOutcome
} = require('./predictionMemoryService');

const {
  resolvePredictionFinalPrice
} = require('./predictionPriceResolverService');

function finiteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeDirection(value) {
  const direction = String(value || '').trim().toLowerCase();

  if (direction === 'rising') return 'rising';
  if (direction === 'falling') return 'falling';
  if (direction === 'stable') return 'stable';

  return null;
}

function calculateActualDirection(
  returnPercent,
  stableThresholdPercent = 1
) {
  if (returnPercent > stableThresholdPercent) {
    return 'rising';
  }

  if (returnPercent < -stableThresholdPercent) {
    return 'falling';
  }

  return 'stable';
}

function evaluatePrediction(
  predictionRecord,
  finalPrice,
  options = {}
) {
  const startingPrice = finiteNumber(
    predictionRecord?.prediction?.currentPrice
  );

  const closingPrice = finiteNumber(finalPrice);

  if (startingPrice == null || startingPrice <= 0) {
    throw new Error('Tahminin başlangıç fiyatı geçersiz.');
  }

  if (closingPrice == null || closingPrice <= 0) {
    throw new Error('Vade sonu fiyatı geçersiz.');
  }

  const predictedDirection = normalizeDirection(
    predictionRecord?.prediction?.direction
  );

  if (!predictedDirection) {
    throw new Error('Tahmin yönü geçersiz.');
  }

  const stableThresholdPercent = Math.max(
    0,
    finiteNumber(options.stableThresholdPercent) ?? 1
  );

  const returnPercent =
    ((closingPrice - startingPrice) / startingPrice) * 100;

  const actualDirection = calculateActualDirection(
    returnPercent,
    stableThresholdPercent
  );

  const isCorrect = predictedDirection === actualDirection;

  return {
    result: isCorrect ? 'correct' : 'incorrect',
    isCorrect,
    predictedDirection,
    actualDirection,
    startingPrice,
    finalPrice: closingPrice,
    returnPercent: Number(returnPercent.toFixed(4)),
    stableThresholdPercent
  };
}

function evaluateDuePredictionByPrice(
  predictionId,
  finalPrice,
  options = {}
) {
  const duePrediction = getDuePredictions().find(
    prediction => prediction.id === predictionId
  );

  if (!duePrediction) {
    return null;
  }

  const outcome = evaluatePrediction(
    duePrediction,
    finalPrice,
    options
  );

  return updatePredictionOutcome(
    predictionId,
    outcome
  );
}

function evaluateAllDuePredictions(priceResolver, options = {}) {
  if (typeof priceResolver !== 'function') {
    throw new Error('priceResolver bir fonksiyon olmalıdır.');
  }

  const duePredictions = getDuePredictions();
  const results = [];

  for (const prediction of duePredictions) {
    try {
      const finalPrice = priceResolver(prediction);

      if (finalPrice == null) {
        results.push({
          id: prediction.id,
          status: 'skipped',
          reason: 'final_price_not_found'
        });

        continue;
      }

      const updated = evaluateDuePredictionByPrice(
        prediction.id,
        finalPrice,
        options
      );

      results.push({
        id: prediction.id,
        status: updated ? 'evaluated' : 'skipped',
        record: updated || null
      });
    } catch (error) {
      results.push({
        id: prediction.id,
        status: 'failed',
        error: error.message
      });
    }
  }

  return {
    total: duePredictions.length,
    evaluated: results.filter(
      item => item.status === 'evaluated'
    ).length,
    skipped: results.filter(
      item => item.status === 'skipped'
    ).length,
    failed: results.filter(
      item => item.status === 'failed'
    ).length,
    results
  };
}

async function evaluateAllDuePredictionsWithMarketData(options = {}) {
  const {
    priceResolver = resolvePredictionFinalPrice,
    ...evaluationOptions
  } = options;
  const duePredictions = getDuePredictions();
  const results = [];

  for (const prediction of duePredictions) {
    try {
      const finalPrice = await priceResolver(
        prediction,
        evaluationOptions
      );

      if (finalPrice == null) {
        results.push({
          id: prediction.id,
          symbol: prediction?.asset?.symbol || null,
          status: 'skipped',
          reason: 'final_price_not_found'
        });

        continue;
      }

      const updated = evaluateDuePredictionByPrice(
        prediction.id,
        finalPrice,
        evaluationOptions
      );

      results.push({
        id: prediction.id,
        symbol: prediction?.asset?.symbol || null,
        status: updated ? 'evaluated' : 'skipped',
        finalPrice,
        record: updated || null
      });
    } catch (error) {
      results.push({
        id: prediction.id,
        symbol: prediction?.asset?.symbol || null,
        status: 'failed',
        error: error.message
      });
    }
  }

  return {
    total: duePredictions.length,
    evaluated: results.filter(
      item => item.status === 'evaluated'
    ).length,
    skipped: results.filter(
      item => item.status === 'skipped'
    ).length,
    failed: results.filter(
      item => item.status === 'failed'
    ).length,
    results
  };
}

module.exports = {
  evaluatePrediction,
  calculateActualDirection,
  evaluateDuePredictionByPrice,
  evaluateAllDuePredictions,
  evaluateAllDuePredictionsWithMarketData
};
