const OpenAI = require("openai");

let openai = null;

// API anahtarı varsa OpenAI'yi başlat
if (process.env.OPENAI_API_KEY && process.env.OPENAI_API_KEY.trim() !== "") {
  openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  console.log("✅ Trendora AI aktif.");
} else {
  console.warn("⚠️ Trendora AI devre dışı (OPENAI_API_KEY bulunamadı).");
}

async function askTrendora(message) {
  if (!message || message.trim() === "") {
    throw new Error("Mesaj boş olamaz.");
  }

  // AI kapalıysa sunucuyu çökertme
  if (!openai) {
    return "Trendora AI şu anda devre dışı. OpenAI API anahtarı veya bakiyesi bulunmadığı için cevap veremiyor.";
  }

  try {
    const response = await openai.responses.create({
      model: "gpt-4.1-mini",
      instructions:
        "Sen Trendora AI'sın. Türkçe konuş. Trendleri, haberleri, teknoloji ve piyasaları anlaşılır şekilde analiz et. Bilmediğin bilgileri uydurma.",
      input: message,
    });

    return response.output_text;
  } catch (err) {
    console.error("OpenAI Hatası:", err.message);

    if (err.status === 429) {
      return "Trendora AI şu anda kullanılamıyor. OpenAI kotası veya bakiyesi tükenmiş.";
    }

    return "Trendora AI şu anda geçici olarak hizmet veremiyor.";
  }
}

module.exports = {
  askTrendora,
};