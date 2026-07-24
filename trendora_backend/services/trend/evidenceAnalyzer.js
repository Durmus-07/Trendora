const OFFICIAL_DOMAINS = [
  'kap.org.tr',
  'borsaistanbul.com',
  'tcmb.gov.tr',
  'tuik.gov.tr',
  'spk.gov.tr'
];

const HIGH_TRUST_DOMAINS = [
  'reuters.com',
  'bloomberg.com',
  'aa.com.tr',
  'trthaber.com',
  'finance.yahoo.com'
];

const POSITIVE_TERMS = [
  'rekor', 'sözleşme', 'ihale', 'yatırım', 'kapasite artışı', 'büyüme',
  'kâr artışı', 'kar artışı', 'ciro artışı', 'temettü', 'geri alım',
  'yükseliş', 'artış', 'güçlü', 'pozitif', 'olumlu', 'hedef yükseltti',
  'beklentiyi aştı', 'onay aldı', 'anlaşma', 'ihracat'
];

const NEGATIVE_TERMS = [
  'zarar', 'dava', 'ceza', 'soruşturma', 'iptal', 'temerrüt', 'iflas',
  'daralma', 'düşüş', 'gerileme', 'zayıf', 'negatif', 'olumsuz',
  'hedef düşürdü', 'beklentinin altında', 'borç artışı', 'satış baskısı',
  'uyarı', 'risk'
];

const EVENT_RULES = [
  { key: 'kap', label: 'KAP / resmî açıklama', pattern: /\bkap\b|kamuyu aydınlatma|özel durum açıklaması/i },
  { key: 'contract', label: 'Sözleşme ve ihale', pattern: /sözleşme|ihale|sipariş|anlaşma/i },
  { key: 'financials', label: 'Bilanço ve finansal sonuç', pattern: /bilanço|finansal sonuç|net k[aâ]r|ciro|favök|faaliyet k[aâ]rı/i },
  { key: 'dividend', label: 'Temettü ve geri alım', pattern: /temettü|k[aâ]r payı|geri alım/i },
  { key: 'rating', label: 'Hedef fiyat ve kurum görüşü', pattern: /hedef fiyat|tavsiye|notunu|derecelendirme/i },
  { key: 'regulatory', label: 'Düzenleyici ve hukuki gelişme', pattern: /spk|rekabet kurumu|dava|ceza|soruşturma/i }
];

function normalize(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/\s+/g, ' ')
    .trim();
}

function getHostname(value) {
  try {
    return new URL(String(value || '')).hostname.replace(/^www\./, '').toLowerCase();
  } catch (_) {
    return '';
  }
}

function domainMatches(hostname, domain) {
  return hostname === domain || hostname.endsWith(`.${domain}`);
}

function sourceWeight(item) {
  const hostname = getHostname(item?.url || item?.link);
  if (OFFICIAL_DOMAINS.some(domain => domainMatches(hostname, domain))) return 100;
  if (HIGH_TRUST_DOMAINS.some(domain => domainMatches(hostname, domain))) return 88;
  if (/investing|tradingview|bigpara|mynet|doviz/.test(hostname)) return 76;
  if (/youtube|x\.com|threads/.test(hostname)) return 45;
  return hostname ? 62 : 35;
}

function countTerms(text, terms) {
  return terms.reduce((total, term) => total + (text.includes(term) ? 1 : 0), 0);
}

function ageWeight(publishedAt) {
  const time = Date.parse(publishedAt || '');
  if (!Number.isFinite(time)) return 0.7;
  const days = Math.max(0, (Date.now() - time) / 86400000);
  if (days <= 2) return 1;
  if (days <= 7) return 0.9;
  if (days <= 30) return 0.72;
  return 0.5;
}

function analyzeEvidence(items) {
  const evidence = Array.isArray(items) ? items : [];
  const publishers = new Set();
  const domains = new Set();
  const events = new Map();
  let positive = 0;
  let negative = 0;
  let neutral = 0;
  let weightedQuality = 0;
  let qualityDenominator = 0;
  let officialCount = 0;

  for (const item of evidence) {
    const text = normalize(`${item?.title || ''} ${item?.summary || ''}`);
    const hostname = getHostname(item?.url || item?.link);
    const quality = sourceWeight(item);
    const recency = ageWeight(item?.publishedAt);
    const pos = countTerms(text, POSITIVE_TERMS);
    const neg = countTerms(text, NEGATIVE_TERMS);
    const itemWeight = quality * recency;

    if (hostname) domains.add(hostname);
    if (item?.source || item?.publisher) publishers.add(String(item.source || item.publisher));
    if (quality === 100) officialCount += 1;

    weightedQuality += itemWeight;
    qualityDenominator += recency;

    if (pos > neg) positive += itemWeight;
    else if (neg > pos) negative += itemWeight;
    else neutral += itemWeight;

    for (const rule of EVENT_RULES) {
      if (rule.pattern.test(text)) {
        events.set(rule.key, {
          label: rule.label,
          count: (events.get(rule.key)?.count || 0) + 1
        });
      }
    }
  }

  const sentimentTotal = positive + negative + neutral;
  const sentimentScore = sentimentTotal > 0
    ? Math.round(Math.max(0, Math.min(100, 50 + ((positive - negative) / sentimentTotal) * 50)))
    : 50;
  const qualityScore = qualityDenominator > 0
    ? Math.round(weightedQuality / qualityDenominator)
    : 0;
  const diversityScore = Math.min(100, domains.size * 14 + publishers.size * 6);
  const coverageScore = Math.min(100, evidence.length * 5);
  const newsImpact = Math.round(
    Math.min(100, coverageScore * 0.45 + diversityScore * 0.25 + Math.abs(sentimentScore - 50) * 0.6)
  );

  const eventList = [...events.values()].sort((a, b) => b.count - a.count);
  const signals = [];

  if (evidence.length) {
    signals.push({
      type: sentimentScore >= 58 ? 'positive' : sentimentScore <= 42 ? 'negative' : 'neutral',
      title: 'Haber duyarlılığı',
      detail: `${evidence.length} benzersiz içerikte duyarlılık puanı ${sentimentScore}/100; ${domains.size} alan adı tarandı.`,
      weight: Math.max(15, Math.min(90, Math.round((coverageScore + qualityScore) / 2)))
    });
  }

  if (officialCount > 0) {
    signals.push({
      type: 'neutral',
      title: 'Resmî kaynak kapsamı',
      detail: `${officialCount} resmî kaynak veya resmî açıklama bağlantısı bulundu.`,
      weight: Math.min(95, 55 + officialCount * 8)
    });
  }

  for (const event of eventList.slice(0, 3)) {
    signals.push({
      type: 'neutral',
      title: event.label,
      detail: `${event.count} ilgili başlık tespit edildi.`,
      weight: Math.min(80, 30 + event.count * 10)
    });
  }

  return {
    itemCount: evidence.length,
    publisherCount: publishers.size,
    domainCount: domains.size,
    officialCount,
    sentimentScore,
    qualityScore,
    diversityScore,
    coverageScore,
    newsImpact,
    events: eventList,
    signals,
    keyFactors: [
      evidence.length ? `${evidence.length} güncel ve benzersiz içerik` : null,
      domains.size ? `${domains.size} farklı kaynak alan adı` : null,
      officialCount ? `${officialCount} resmî kaynak bağlantısı` : null,
      eventList[0] ? `Öne çıkan olay türü: ${eventList[0].label}` : null
    ].filter(Boolean)
  };
}

module.exports = {
  analyzeEvidence,
  sourceWeight,
  getHostname
};
