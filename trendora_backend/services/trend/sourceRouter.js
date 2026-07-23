function buildSourcePlan(classification) {
  const domain = classification?.domain || 'general';
  const subtype = classification?.entity?.subtype || null;
  const intent = classification?.intent || 'general_analysis';

  const plans = {
    finance: {
      required: ['Resmî piyasa veya ihraççı verisi', 'Güncel fiyat verisi', 'Güvenilir finans haberleri'],
      preferredDomains: ['kap.org.tr', 'borsaistanbul.com', 'tcmb.gov.tr', 'tradingview.com', 'investing.com', 'reuters.com'],
      evidenceTypes: ['official', 'market-data', 'news'],
      notes: []
    },
    real_estate: {
      required: ['İlan örnekleri', 'Konum ve imar verisi', 'Bölgesel fiyat karşılaştırması'],
      preferredDomains: ['sahibinden.com', 'emlakjet.com', 'endeksa.com', 'tkgm.gov.tr', 'belediye.gov.tr'],
      evidenceTypes: ['listing', 'official', 'market-data'],
      notes: []
    },
    vehicle: {
      required: ['Güncel ilan örnekleri', 'Model-yıl-km karşılaştırması', 'Donanım ve hasar bilgisi'],
      preferredDomains: ['sahibinden.com', 'arabam.com', 'marka-resmi-siteleri'],
      evidenceTypes: ['listing', 'official', 'review'],
      notes: []
    },
    product: {
      required: ['Güncel mağaza fiyatları', 'Ürün özellikleri', 'Fiyat geçmişi veya kampanya bilgisi'],
      preferredDomains: ['trendyol.com', 'hepsiburada.com', 'amazon.com.tr', 'mediamarkt.com.tr'],
      evidenceTypes: ['retail', 'official', 'review'],
      notes: []
    },
    general: {
      required: ['Güncel ve güvenilir açık kaynaklar'],
      preferredDomains: [],
      evidenceTypes: ['web', 'news'],
      notes: []
    }
  };

  const plan = { ...(plans[domain] || plans.general) };
  plan.required = [...plan.required];
  plan.preferredDomains = [...plan.preferredDomains];
  plan.evidenceTypes = [...plan.evidenceTypes];
  plan.notes = [...plan.notes];

  if (domain === 'finance' && subtype === 'bist_stock') {
    plan.required.unshift('BIST hisse sembolü ve şirket eşleşmesi');
    plan.preferredDomains.unshift('kap.org.tr', 'borsaistanbul.com');
    plan.notes.push('Günlük kart için yalnız açılış, günlük ortalama ve kapanış kullanılmalı.');
    plan.notes.push('52 haftalık kart için yalnız en düşük, ortalama ve en yüksek kullanılmalı.');
  }

  if (domain === 'finance' && subtype === 'certificate') {
    plan.preferredDomains.unshift('darphane.gov.tr', 'borsaistanbul.com');
  }

  if (intent === 'news_impact') {
    plan.required.push('Son dönem haber akışı ve olay zaman çizelgesi');
    plan.evidenceTypes.push('news');
  }

  if (intent === 'fundamental_analysis') {
    plan.required.push('Finansal tablolar ve şirket açıklamaları');
    plan.evidenceTypes.push('financial-report');
  }

  if (intent === 'technical_analysis') {
    plan.required.push('Tarihsel fiyat serisi ve işlem hacmi');
    plan.evidenceTypes.push('time-series');
  }

  return plan;
}

module.exports = {
  buildSourcePlan
};
