function normalizeText(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/[’'`]/g, '')
    .replace(/[^a-z0-9çğıöşü\.\-\s]/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeTicker(value) {
  return String(value || '')
    .toLocaleUpperCase('tr-TR')
    .replace(/İ/g, 'I')
    .replace(/[^A-Z0-9\.]/g, '')
    .trim();
}

const BIST_ENTITIES = [
  { symbol: 'AEFES', name: 'Anadolu Efes', aliases: ['anadolu efes', 'efes'] },
  { symbol: 'AGHOL', name: 'AG Anadolu Grubu Holding', aliases: ['anadolu grubu', 'ag holding'] },
  { symbol: 'AKBNK', name: 'Akbank', aliases: ['akbank', 'ak bank'] },
  { symbol: 'AKSA', name: 'Aksa Akrilik', aliases: ['aksa akrilik', 'aksa'] },
  { symbol: 'AKSEN', name: 'Aksa Enerji', aliases: ['aksa enerji'] },
  { symbol: 'ALARK', name: 'Alarko Holding', aliases: ['alarko', 'alarko holding'] },
  { symbol: 'ARCLK', name: 'Arçelik', aliases: ['arçelik', 'arcelik'] },
  { symbol: 'ASELS', name: 'ASELSAN', aliases: ['aselsan', 'asels'] },
  { symbol: 'ASTOR', name: 'Astor Enerji', aliases: ['astor', 'astor enerji'] },
  { symbol: 'BIMAS', name: 'BİM Birleşik Mağazalar', aliases: ['bim', 'bim market', 'bim birleşik mağazalar', 'bimas'] },
  { symbol: 'BRSAN', name: 'Borusan Mannesmann', aliases: ['borusan mannesmann', 'borusan boru'] },
  { symbol: 'CCOLA', name: 'Coca-Cola İçecek', aliases: ['coca cola içecek', 'coca cola icecek', 'ccola'] },
  { symbol: 'CIMSA', name: 'Çimsa', aliases: ['çimsa', 'cimsa'] },
  { symbol: 'DOAS', name: 'Doğuş Otomotiv', aliases: ['doğuş otomotiv', 'dogus otomotiv', 'doas'] },
  { symbol: 'EKGYO', name: 'Emlak Konut GYO', aliases: ['emlak konut', 'emlak konut gyo'] },
  { symbol: 'ENJSA', name: 'Enerjisa Enerji', aliases: ['enerjisa', 'enerjisa enerji'] },
  { symbol: 'ENKAI', name: 'Enka İnşaat', aliases: ['enka', 'enka inşaat', 'enka insaat'] },
  { symbol: 'EREGL', name: 'Ereğli Demir ve Çelik', aliases: ['ereğli', 'eregli', 'erdemir', 'ereğli demir çelik'] },
  { symbol: 'FROTO', name: 'Ford Otosan', aliases: ['ford otosan', 'ford oto sanayi', 'froto'] },
  { symbol: 'GARAN', name: 'Garanti BBVA', aliases: ['garanti', 'garanti bankası', 'garanti bbva'] },
  { symbol: 'GUBRF', name: 'Gübre Fabrikaları', aliases: ['gübre fabrikaları', 'gubre fabrikalari', 'gubrf'] },
  { symbol: 'HEKTS', name: 'Hektaş', aliases: ['hektaş', 'hektas'] },
  { symbol: 'ISCTR', name: 'Türkiye İş Bankası C', aliases: ['iş bankası', 'is bankasi', 'iş c', 'isctr'] },
  { symbol: 'KCHOL', name: 'Koç Holding', aliases: ['koç', 'koc', 'koç holding', 'koc holding'] },
  { symbol: 'KONTR', name: 'Kontrolmatik', aliases: ['kontrolmatik', 'kontr'] },
  { symbol: 'KOZAA', name: 'Koza Anadolu Metal', aliases: ['koza anadolu', 'kozaa'] },
  { symbol: 'KOZAL', name: 'Koza Altın', aliases: ['koza altın', 'koza altin', 'kozal'] },
  { symbol: 'MGROS', name: 'Migros', aliases: ['migros', 'mgros'] },
  { symbol: 'ODAS', name: 'Odaş Elektrik', aliases: ['odaş', 'odas', 'odaş elektrik'] },
  { symbol: 'OYAKC', name: 'Oyak Çimento', aliases: ['oyak çimento', 'oyak cimento'] },
  { symbol: 'PETKM', name: 'Petkim', aliases: ['petkim'] },
  { symbol: 'PGSUS', name: 'Pegasus', aliases: ['pegasus', 'pegasus hava yolları', 'pgsus'] },
  { symbol: 'SAHOL', name: 'Sabancı Holding', aliases: ['sabancı', 'sabanci', 'sabancı holding'] },
  { symbol: 'SASA', name: 'Sasa Polyester', aliases: ['sasa', 'sasa polyester'] },
  { symbol: 'SISE', name: 'Şişecam', aliases: ['şişecam', 'sisecam', 'şişe cam', 'sise'] },
  { symbol: 'SOKM', name: 'Şok Marketler', aliases: ['şok', 'sok', 'şok market', 'sok market'] },
  { symbol: 'TAVHL', name: 'TAV Havalimanları', aliases: ['tav', 'tav havalimanları'] },
  { symbol: 'TCELL', name: 'Turkcell', aliases: ['turkcell', 'tcell'] },
  { symbol: 'THYAO', name: 'Türk Hava Yolları', aliases: ['thy', 'türk hava yolları', 'turk hava yollari', 'thy ao', 'thyao'] },
  { symbol: 'TKFEN', name: 'Tekfen Holding', aliases: ['tekfen', 'tekfen holding'] },
  { symbol: 'TOASO', name: 'Tofaş', aliases: ['tofaş', 'tofas', 'tofaş oto', 'toaso'] },
  { symbol: 'TTKOM', name: 'Türk Telekom', aliases: ['türk telekom', 'turk telekom', 'ttkom'] },
  { symbol: 'TUPRS', name: 'Tüpraş', aliases: ['tüpraş', 'tupras', 'tüpraş hissesi'] },
  { symbol: 'ULKER', name: 'Ülker Bisküvi', aliases: ['ülker', 'ulker', 'ülker bisküvi'] },
  { symbol: 'VAKBN', name: 'VakıfBank', aliases: ['vakıfbank', 'vakifbank', 'vakbn'] },
  { symbol: 'VESTL', name: 'Vestel', aliases: ['vestel'] },
  { symbol: 'YKBNK', name: 'Yapı Kredi', aliases: ['yapı kredi', 'yapi kredi', 'yapı ve kredi bankası'] },
  { symbol: 'ALTIN.S1', name: 'Darphane Altın Sertifikası', aliases: ['altın s1', 'altin s1', 'altın.s1', 'altin.s1', 'altın sertifikası', 'darphane altın sertifikası'] }
];

const OTHER_FINANCE_ENTITIES = [
  { symbol: 'XAUUSD', name: 'Ons Altın', subtype: 'commodity', aliases: ['ons altın', 'ons altin', 'xauusd'] },
  { symbol: 'GRAM_ALTIN', name: 'Gram Altın', subtype: 'commodity', aliases: ['gram altın', 'gram altin', 'gram'] },
  { symbol: 'XAGUSD', name: 'Ons Gümüş', subtype: 'commodity', aliases: ['ons gümüş', 'ons gumus', 'xagusd', 'gümüş', 'gumus'] },
  { symbol: 'USDTRY', name: 'Dolar/TL', subtype: 'fx', aliases: ['dolar', 'dolar tl', 'usdtry', 'usd try'] },
  { symbol: 'EURTRY', name: 'Euro/TL', subtype: 'fx', aliases: ['euro', 'avro', 'euro tl', 'eurtry'] },
  { symbol: 'BTC', name: 'Bitcoin', subtype: 'crypto', aliases: ['bitcoin', 'btc'] },
  { symbol: 'ETH', name: 'Ethereum', subtype: 'crypto', aliases: ['ethereum', 'ether', 'eth'] },
  { symbol: 'SOL', name: 'Solana', subtype: 'crypto', aliases: ['solana', 'sol'] },
  { symbol: 'XRP', name: 'XRP', subtype: 'crypto', aliases: ['xrp', 'ripple'] }
];

const BIST_BY_SYMBOL = new Map(BIST_ENTITIES.map(item => [item.symbol, item]));

function tokenBoundaryIncludes(text, candidate) {
  if (!candidate) return false;
  const escaped = candidate.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(^|\\s)${escaped}(?=\\s|$)`, 'i').test(text);
}

function findBistEntity(query) {
  const normalized = normalizeText(query);
  const upperQuery = normalizeTicker(query);

  const explicitSymbols = upperQuery.match(/[A-Z]{4,6}(?:\.S1)?/g) || [];
  for (const symbol of explicitSymbols) {
    if (BIST_BY_SYMBOL.has(symbol)) {
      const item = BIST_BY_SYMBOL.get(symbol);
      return {
        found: true,
        domain: 'finance',
        subtype: symbol.endsWith('.S1') ? 'certificate' : 'bist_stock',
        market: 'BIST',
        symbol: item.symbol,
        name: item.name,
        matchedBy: 'symbol',
        matchedValue: symbol,
        confidence: 100
      };
    }
  }

  let best = null;
  for (const item of BIST_ENTITIES) {
    const candidates = [item.symbol.toLocaleLowerCase('tr-TR'), ...item.aliases]
      .map(normalizeText)
      .sort((a, b) => b.length - a.length);

    for (const alias of candidates) {
      if (tokenBoundaryIncludes(normalized, alias)) {
        const score = alias === item.symbol.toLocaleLowerCase('tr-TR') ? 98 : Math.min(96, 76 + alias.length);
        if (!best || score > best.confidence) {
          best = {
            found: true,
            domain: 'finance',
            subtype: item.symbol.endsWith('.S1') ? 'certificate' : 'bist_stock',
            market: 'BIST',
            symbol: item.symbol,
            name: item.name,
            matchedBy: 'alias',
            matchedValue: alias,
            confidence: score
          };
        }
      }
    }
  }

  return best;
}

function findOtherFinanceEntity(query) {
  const normalized = normalizeText(query);
  let best = null;

  for (const item of OTHER_FINANCE_ENTITIES) {
    const candidates = [item.symbol.toLocaleLowerCase('tr-TR'), ...item.aliases]
      .map(normalizeText)
      .sort((a, b) => b.length - a.length);

    for (const alias of candidates) {
      if (tokenBoundaryIncludes(normalized, alias)) {
        const score = alias === item.symbol.toLocaleLowerCase('tr-TR') ? 98 : Math.min(95, 74 + alias.length);
        if (!best || score > best.confidence) {
          best = {
            found: true,
            domain: 'finance',
            subtype: item.subtype,
            market: item.subtype === 'crypto' ? 'CRYPTO' : item.subtype === 'fx' ? 'FX' : 'COMMODITY',
            symbol: item.symbol,
            name: item.name,
            matchedBy: 'alias',
            matchedValue: alias,
            confidence: score
          };
        }
      }
    }
  }

  return best;
}

function resolveEntity(query) {
  return findBistEntity(query) || findOtherFinanceEntity(query) || {
    found: false,
    domain: null,
    subtype: null,
    market: null,
    symbol: null,
    name: null,
    matchedBy: null,
    matchedValue: null,
    confidence: 0
  };
}

module.exports = {
  resolveEntity,
  normalizeText,
  normalizeTicker,
  BIST_ENTITIES
};
