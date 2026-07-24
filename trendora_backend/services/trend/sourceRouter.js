const SOURCE_CATALOG = {
  official: [
    { id: 'kap', name: 'KAP', domain: 'kap.org.tr', type: 'official-disclosure', priority: 100 },
    { id: 'bist', name: 'Borsa İstanbul', domain: 'borsaistanbul.com', type: 'official-market', priority: 100 },
    { id: 'tcmb', name: 'TCMB', domain: 'tcmb.gov.tr', type: 'official-macro', priority: 95 },
    { id: 'tuik', name: 'TÜİK', domain: 'tuik.gov.tr', type: 'official-statistics', priority: 90 }
  ],
  market: [
    { id: 'yahoo', name: 'Yahoo Finance', domain: 'finance.yahoo.com', type: 'market-data', priority: 90 },
    { id: 'tradingview', name: 'TradingView', domain: 'tradingview.com', type: 'market-analysis', priority: 85 },
    { id: 'investing', name: 'Investing', domain: 'investing.com', type: 'market-analysis', priority: 85 },
    { id: 'google-finance', name: 'Google Finance', domain: 'google.com', type: 'market-data', priority: 75 },
    { id: 'bigpara', name: 'Bigpara', domain: 'bigpara.hurriyet.com.tr', type: 'market-news', priority: 75 },
    { id: 'mynet-finans', name: 'Mynet Finans', domain: 'finans.mynet.com', type: 'market-news', priority: 70 },
    { id: 'doviz-com', name: 'Döviz.com', domain: 'doviz.com', type: 'market-data', priority: 75 }
  ],
  social: [
    { id: 'x', name: 'X', domain: 'x.com', type: 'social-signal', priority: 55, directApiRequiresCredentials: true },
    { id: 'threads', name: 'Threads', domain: 'threads.net', type: 'social-signal', priority: 45, directApiRequiresCredentials: true },
    { id: 'youtube', name: 'YouTube', domain: 'youtube.com', type: 'video-signal', priority: 60, directApiRequiresCredentials: true }
  ],
  indices: [
    { id: 'xu100', name: 'BIST 100', symbol: 'XU100', type: 'index', priority: 95 },
    { id: 'xu030', name: 'BIST 30', symbol: 'XU030', type: 'index', priority: 95 }
  ]
};

function unique(values) {
  return [...new Set((values || []).filter(Boolean))];
}

function flattenSources(groups) {
  return groups.flatMap(group => SOURCE_CATALOG[group] || []);
}

function buildFinanceSources(subtype, intent) {
  const groups = ['official', 'market', 'social', 'indices'];
  const sources = flattenSources(groups);

  if (subtype === 'bist_stock') {
    sources.sort((a, b) => {
      const aOfficial = ['kap', 'bist', 'xu100', 'xu030'].includes(a.id) ? 1 : 0;
      const bOfficial = ['kap', 'bist', 'xu100', 'xu030'].includes(b.id) ? 1 : 0;
      if (aOfficial !== bOfficial) return bOfficial - aOfficial;
      return (b.priority || 0) - (a.priority || 0);
    });
  }

  if (intent === 'news_impact') {
    sources.sort((a, b) => {
      const aSocial = ['social-signal', 'video-signal', 'market-news', 'official-disclosure'].includes(a.type) ? 1 : 0;
      const bSocial = ['social-signal', 'video-signal', 'market-news', 'official-disclosure'].includes(b.type) ? 1 : 0;
      if (aSocial !== bSocial) return bSocial - aSocial;
      return (b.priority || 0) - (a.priority || 0);
    });
  }

  return sources;
}

function buildSourcePlan(classification) {
  const domain = classification?.domain || 'general';
  const subtype = classification?.entity?.subtype || null;
  const intent = classification?.intent || 'general_analysis';

  const plans = {
    finance: {
      required: [
        'Resmî şirket açıklamaları ve KAP bildirimleri',
        'Borsa İstanbul ve endeks karşılaştırmaları',
        'Güncel fiyat, hacim ve tarihsel fiyat serisi',
        'Teknik gösterge ve piyasa eğilimi',
        'Finans haberleri ile sosyal ilgi sinyalleri'
      ],
      evidenceTypes: ['official', 'market-data', 'time-series', 'news', 'social-signal'],
      notes: [
        'Resmî kaynaklar ve doğrudan piyasa verileri sosyal sinyallerden daha yüksek ağırlık alır.',
        'X, Threads ve YouTube tek başına fiyat tahmini üretmez; yalnızca ilgi ve duyarlılık sinyali olarak kullanılır.',
        'Erişilemeyen kaynak yüzünden analiz durmaz; diğer kaynaklarla devam edilir.',
        'Yeni bulunan kaynaklar yalnız alan adı, yayıncı ve içerik türü doğrulanırsa keşif havuzuna eklenir.'
      ]
    },
    real_estate: {
      required: ['İlan örnekleri', 'Konum ve imar verisi', 'Bölgesel fiyat karşılaştırması'],
      preferredDomains: ['sahibinden.com', 'emlakjet.com', 'endeksa.com', 'tkgm.gov.tr'],
      evidenceTypes: ['listing', 'official', 'market-data'],
      notes: []
    },
    vehicle: {
      required: ['Güncel ilan örnekleri', 'Model-yıl-km karşılaştırması', 'Donanım ve hasar bilgisi'],
      preferredDomains: ['sahibinden.com', 'arabam.com'],
      evidenceTypes: ['listing', 'official', 'review'],
      notes: []
    },
    product: {
      required: ['Güncel mağaza fiyatları', 'Ürün özellikleri', 'Fiyat geçmişi veya kampanya bilgisi'],
      preferredDomains: ['trendyol.com', 'hepsiburada.com', 'amazon.com.tr', 'mediamarkt.com.tr'],
      evidenceTypes: ['retail', 'official', 'review'],
      notes: []
    },
    travel: {
      required: ['Güncel ulaşım ve konaklama verisi', 'Resmî seyahat bilgileri', 'Mevsim ve yoğunluk göstergeleri'],
      preferredDomains: ['kulturportali.gov.tr', 'goturkiye.com', 'dhmi.gov.tr', 'tcddtasimacilik.gov.tr'],
      evidenceTypes: ['official', 'travel-data', 'review'],
      notes: ['Fiyat ve uygunluk bilgileri tarih belirtilmeden kesin kabul edilmemeli.']
    },
    business: {
      required: ['Sektör büyüklüğü ve talep göstergeleri', 'Resmî şirket ve istihdam verileri', 'Rakip ve maliyet karşılaştırması'],
      preferredDomains: ['tuik.gov.tr', 'iskur.gov.tr', 'ticaret.gov.tr', 'kosgeb.gov.tr'],
      evidenceTypes: ['official', 'market-data', 'business-news'],
      notes: []
    },
    job: {
      required: ['Güncel iş ilanı örnekleri', 'Meslek ve ücret göstergeleri', 'Resmî istihdam verileri'],
      preferredDomains: ['iskur.gov.tr', 'tuik.gov.tr', 'kariyer.net', 'linkedin.com'],
      evidenceTypes: ['official', 'listing', 'market-data'],
      notes: []
    },
    general: {
      required: ['Güncel ve güvenilir açık kaynaklar'],
      preferredDomains: [],
      evidenceTypes: ['web', 'news'],
      notes: ['Yeni kaynaklar otomatik keşif ile bulunabilir; doğrulanmadan yüksek güvenli kanıt sayılmaz.']
    }
  };

  const base = plans[domain] || plans.general;
  const plan = {
    required: [...base.required],
    preferredDomains: [...(base.preferredDomains || [])],
    evidenceTypes: [...base.evidenceTypes],
    notes: [...base.notes],
    sources: [],
    discovery: {
      enabled: true,
      mode: 'verified-web-discovery',
      maxNewSourcesPerAnalysis: 5,
      rules: [
        'Kaynak HTTPS kullanmalı.',
        'Yayıncı adı ve alan adı açık olmalı.',
        'İçerik tarihi veya güncellik işareti bulunmalı.',
        'Aynı haberin kopyaları tek kaynak sayılmalı.',
        'Resmî kaynakla çelişen sosyal içerik düşük ağırlık almalı.'
      ]
    }
  };

  if (domain === 'finance') {
    plan.sources = buildFinanceSources(subtype, intent);
    plan.preferredDomains = unique(plan.sources.map(source => source.domain));

    if (subtype === 'bist_stock') {
      plan.required.unshift('BIST hisse sembolü ve şirket eşleşmesi');
      plan.notes.push('KAP ve Borsa İstanbul verileri bulunursa ilk sırada kullanılmalı.');
    }
    if (subtype === 'certificate') {
      plan.preferredDomains = unique(['darphane.gov.tr', ...plan.preferredDomains]);
    }
    if (intent === 'fundamental_analysis') {
      plan.required.push('Finansal tablolar, faaliyet raporları ve yatırımcı ilişkileri açıklamaları');
      plan.evidenceTypes.push('financial-report');
    }
    if (intent === 'technical_analysis') {
      plan.required.push('En az 200 işlem günlük fiyat serisi ve işlem hacmi');
    }
    if (intent === 'news_impact') {
      plan.required.push('Son dönem haber akışı, KAP olayları ve sosyal ilgi zaman çizelgesi');
    }
  }

  return plan;
}

module.exports = {
  SOURCE_CATALOG,
  buildSourcePlan
};
