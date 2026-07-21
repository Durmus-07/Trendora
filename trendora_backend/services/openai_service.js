const OpenAI = require("openai");

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

async function askTrendora(message) {
  if (!message || message.trim() === "") {
    throw new Error("Mesaj boş olamaz.");
  }

  const response = await openai.responses.create({
    model: "gpt-4.1-mini",
    instructions:
      "Sen Trendora AI'sın. Türkçe konuş. Trendleri, haberleri, teknoloji ve piyasaları anlaşılır şekilde analiz et. Bilmediğin bilgileri uydurma.",
    input: message,
  });

  return response.output_text;
}

module.exports = {
  askTrendora,
};