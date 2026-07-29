const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const https = require("https");

initializeApp();

const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;
const MESSAGE_MAX_LENGTH = 2000;

function escapeSlackMrkdwn(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

exports.submitFeedback = onRequest(
  { region: "asia-northeast1", cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const { message, appVersion, osVersion, deviceModel } = req.body;

    if (!message) {
      res.status(400).json({ error: "message is required" });
      return;
    }

    if (message.length > MESSAGE_MAX_LENGTH) {
      res.status(400).json({ error: `message must be ${MESSAGE_MAX_LENGTH} characters or fewer` });
      return;
    }

    // Firestoreに保存
    const db = getFirestore();
    await db.collection("feedback").add({
      message,
      appVersion: appVersion || "unknown",
      osVersion: osVersion || "unknown",
      deviceModel: deviceModel || "unknown",
      createdAt: FieldValue.serverTimestamp(),
    });

    if (!SLACK_WEBHOOK_URL) {
      console.warn("SLACK_WEBHOOK_URL is not set, skipping Slack notification");
      res.status(200).json({ success: true });
      return;
    }

    // Slack通知
    const escapedMessage = escapeSlackMrkdwn(message);
    await postToSlack({
      text: `:loudspeaker: *読み上げナレーター (VoiceYourText) フィードバックが届きました*`,
      blocks: [
        {
          type: "header",
          text: { type: "plain_text", text: "📩 読み上げナレーター - 新しいフィードバック" },
        },
        {
          type: "section",
          fields: [{ type: "mrkdwn", text: `*メッセージ:*\n${escapedMessage}` }],
        },
        {
          type: "section",
          fields: [
            { type: "mrkdwn", text: `*アプリバージョン:*\n${appVersion || "-"}` },
            { type: "mrkdwn", text: `*iOS:*\n${osVersion || "-"}` },
            { type: "mrkdwn", text: `*デバイス:*\n${deviceModel || "-"}` },
          ],
        },
      ],
    });

    res.status(200).json({ success: true });
  }
);

function postToSlack(body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const url = new URL(SLACK_WEBHOOK_URL);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(payload),
      },
    };
    const req = https.request(options, (res) => {
      res.on("data", () => {});
      res.on("end", resolve);
    });
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}
