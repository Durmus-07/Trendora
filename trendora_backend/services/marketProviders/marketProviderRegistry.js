const yahooProvider = require('./yahooMarketProvider');

const providers = [
  yahooProvider
];

function enabledProviders() {
  return providers.filter((provider) => {
    try {
      return provider.isEnabled();
    } catch (_error) {
      return false;
    }
  });
}

function compactError(error) {
  return {
    code: error?.code || null,
    message: String(error?.message || 'Bilinmeyen sağlayıcı hatası').slice(0, 240)
  };
}

async function fetchMarketChart(symbol, options = {}) {
  const activeProviders = enabledProviders();
  if (!activeProviders.length) {
    const error = new Error('Etkin piyasa veri sağlayıcısı bulunamadı.');
    error.code = 'NO_MARKET_PROVIDER_ENABLED';
    throw error;
  }

  const attempts = [];

  for (const provider of activeProviders) {
    try {
      const response = await provider.fetchChart(symbol, options);
      return {
        ...response,
        providerAttempts: attempts
      };
    } catch (error) {
      attempts.push({
        providerId: provider.id,
        providerName: provider.name,
        ...compactError(error)
      });
    }
  }

  const error = new Error(`Piyasa verisi alınamadı: ${symbol}`);
  error.code = 'ALL_MARKET_PROVIDERS_FAILED';
  error.attempts = attempts;
  throw error;
}

function getProviderStatus() {
  return providers.map((provider, priority) => ({
    id: provider.id,
    name: provider.name,
    priority: priority + 1,
    enabled: Boolean(provider.isEnabled())
  }));
}

module.exports = {
  fetchMarketChart,
  getProviderStatus
};
