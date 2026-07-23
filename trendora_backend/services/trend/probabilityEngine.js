function clamp(value, min, max) {
  return Math.min(Math.max(Number(value) || 0, min), max);
}

function normalizeScenarios(rawScenarios) {
  const scenarios = Array.isArray(rawScenarios)
    ? rawScenarios.slice(0, 5)
    : [];

  if (scenarios.length === 0) {
    return [];
  }

  const prepared = scenarios.map((item, index) => ({
    name: String(item?.name || `Senaryo ${index + 1}`),
    probability: clamp(item?.probability, 0, 100),
    description: String(item?.description || '')
  }));

  const total = prepared.reduce(
    (sum, item) => sum + item.probability,
    0
  );

  if (total <= 0) {
    const equal = Math.floor(100 / prepared.length);
    let remainder = 100 - equal * prepared.length;

    return prepared.map(item => ({
      ...item,
      probability: equal + (remainder-- > 0 ? 1 : 0)
    }));
  }

  const normalized = prepared.map(item => ({
    ...item,
    probability: Math.round((item.probability / total) * 100)
  }));

  const difference =
    100 - normalized.reduce((sum, item) => sum + item.probability, 0);

  normalized[0].probability = clamp(
    normalized[0].probability + difference,
    0,
    100
  );

  return normalized;
}

function confidenceLabel(value) {
  const score = clamp(value, 0, 100);
  if (score >= 75) return 'Yüksek';
  if (score >= 50) return 'Orta';
  return 'Düşük';
}

module.exports = {
  clamp,
  normalizeScenarios,
  confidenceLabel
};
