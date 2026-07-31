const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAppCheck } = require("firebase-admin/app-check");
const https = require("https");

initializeApp();

const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;
const MESSAGE_MAX_LENGTH = 2000;

// App Checkを必須にするか。既にストアに出ている旧クライアントはトークンを送らないため、
// 新バージョンが浸透するまでは監視モード(false)で運用し、浸透後にtrueへ切り替える。
// 切り替えはコード変更不要（Cloud Functionsの環境変数 APP_CHECK_ENFORCED=true）。
const APP_CHECK_ENFORCED = process.env.APP_CHECK_ENFORCED === "true";

function escapeSlackMrkdwn(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/**
 * X-Firebase-AppCheckヘッダを検証する。
 * onRequest(生HTTP)ではonCallの enforceAppCheck が使えないため自前で検証する。
 * @returns {Promise<"valid"|"missing"|"invalid">}
 */
async function verifyAppCheckToken(req) {
  const token = req.header("X-Firebase-AppCheck");
  if (!token) return "missing";
  try {
    await getAppCheck().verifyToken(token);
    return "valid";
  } catch (err) {
    console.warn("App Check token verification failed:", err.message);
    return "invalid";
  }
}

exports.submitFeedback = onRequest(
  { region: "asia-northeast1", cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // App Check検証。不正トークンは常に拒否し、トークン無し(旧クライアント)は
    // APP_CHECK_ENFORCED が有効な場合のみ拒否する（監視モードではwarnのみ）。
    const appCheckResult = await verifyAppCheckToken(req);
    if (appCheckResult === "invalid") {
      res.status(401).json({ error: "Invalid App Check token" });
      return;
    }
    if (appCheckResult === "missing") {
      if (APP_CHECK_ENFORCED) {
        res.status(401).json({ error: "App Check token required" });
        return;
      }
      console.warn("App Check token missing (allowed: enforcement disabled)");
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
      // 必須化に切り替えて良いか判断するため、トークン付きリクエストの割合を記録する
      appCheck: appCheckResult,
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
    // SLACK_WEBHOOK_URL未設定時のガード。呼び出し側でもガードしているが、
    // new URL(undefined)によるTypeErrorで関数全体が失敗するのを防ぐため二重に防御する。
    if (!SLACK_WEBHOOK_URL) {
      console.warn("SLACK_WEBHOOK_URL is not set, skipping Slack notification");
      resolve();
      return;
    }
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
