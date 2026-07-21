const express = require("express");
const { askTrendora } = require("../services/openai_service");

const router = express.Router();

router.post("/", async (req, res) => {
  try {
    const { message } = req.body;

    if (!message || message.trim() === "") {
      return res.status(400).json({
        success: false,
        error: "Mesaj bos olamaz."
      });
    }

    const answer = await askTrendora(message);

    return res.json({
      success: true,
      answer: answer
    });
  } catch (error) {
    console.error("Trendora AI hatasi:", error);

    return res.status(500).json({
      success: false,
      error: error.message || "Yapay zeka cevabi alinamadi."
    });
  }
});

module.exports = router;