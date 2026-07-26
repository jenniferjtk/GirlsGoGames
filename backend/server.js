import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import OpenAI from "openai";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

const port = process.env.PORT || 3000;
const apiKey = process.env.OPENAI_API_KEY;
const model = process.env.OPENAI_MODEL;
const azureKey = process.env.AZURE_KEY;
const azureEndpoint =
  "https://eastus2.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1";

if (!apiKey) {
  console.error("Missing OPENAI_API_KEY in backend/.env");
  process.exit(1);
}

if (!model) {
  console.error("Missing OPENAI_MODEL in backend/.env");
  process.exit(1);
}

if (!azureKey) {
  console.error("Missing AZURE_KEY in backend/.env");
  process.exit(1);
}

const client = new OpenAI({ apiKey });

app.get("/health", (req, res) => {
  res.json({ ok: true });
});

app.post("/generate-story", async (req, res) => {
  try {
    const prompt = String(req.body?.prompt || "").trim();

    if (!prompt) {
      return res.status(400).json({ error: "prompt is required" });
    }
    console.log("📖 Calling OpenAI...");
    const response = await client.responses.create({
      model,
      input: [
        {
          role: "developer",
          content:
            "Write a short, kid-friendly story for a reading app. Use the requested Dolch words naturally. Keep it simple, warm, and appropriate for children. Return only the story text."
        },
        {
          role: "user",
          content: prompt
        }
      ],
      max_output_tokens: 250
    });

    res.json({
      story: (response.output_text || "").trim()
    });
  } catch (error) {
    console.error("Story generation failed:", error);
    res.status(500).json({
      error: "Failed to generate story"
    });
  }
});

app.post(
  "/assess-pronunciation",
  express.raw({ type: "audio/wav", limit: "2mb" }),
  async (req, res) => {
    try {
      const referenceText = String(req.query.referenceText || "").trim();

      if (!referenceText) {
        return res.status(400).json({ error: "referenceText is required" });
      }
      if (!req.body || !req.body.length) {
        return res.status(400).json({ error: "audio body is required" });
      }

      const configJson = {
        referenceText,
        gradingSystem: "HundredMark",
        dimension: "Comprehensive"
      };
      const configBase64 = Buffer.from(JSON.stringify(configJson)).toString(
        "base64"
      );

      console.log("🎤 Calling Azure pronunciation assessment...");
      const azureResponse = await fetch(`${azureEndpoint}?language=en-US`, {
        method: "POST",
        headers: {
          "Ocp-Apim-Subscription-Key": azureKey,
          "Content-Type": "audio/wav",
          "Pronunciation-Assessment": configBase64
        },
        body: req.body
      });

      const text = await azureResponse.text();

      if (!azureResponse.ok) {
        console.error(
          "Azure pronunciation assessment failed:",
          azureResponse.status,
          text
        );
        return res
          .status(azureResponse.status)
          .json({ error: "Azure assessment failed" });
      }

      res.type("application/json").send(text);
    } catch (error) {
      console.error("Pronunciation assessment failed:", error);
      res.status(500).json({ error: "Failed to assess pronunciation" });
    }
  }
);

app.listen(port, () => {
  console.log(`Backend listening on port ${port}`);
});