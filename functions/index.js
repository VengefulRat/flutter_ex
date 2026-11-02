const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendPushNotification = onDocumentCreated(
  "notifications/{notifId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const data = snap.data();
    if (!data) return null;

    const toCode = data.toCode;
    const title = data.title || "Lore";
    const subtitle = data.subtitle || "";
    const type = data.type || "";
    const extraData = data.data || {};

    // Get recipient's FCM token
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(toCode)
      .get();

    if (!userDoc.exists) {
      console.log(`User ${toCode} not found`);
      return null;
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for ${toCode}`);
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: subtitle,
      },
      data: {
        type: type,
        sessionId: extraData.sessionId || "",
        fromCode: extraData.fromCode || "",
        genre: extraData.genre || "",
        notifId: event.params.notifId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "lore_notifications",
          priority: "high",
          defaultSound: true,
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`FCM sent to ${toCode}: ${response}`);
      return null;
    } catch (error) {
      console.error(`FCM failed for ${toCode}:`, error);
      return null;
    }
  }
);
