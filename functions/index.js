const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

async function getUserTokens(userId) {
  if (!userId) return [];

  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  if (!userDoc.exists) return [];

  const singleToken = userDoc.get("fcmToken");
  const tokenList = userDoc.get("fcmTokens");

  const tokens = new Set();
  if (typeof singleToken === "string" && singleToken.trim() !== "") {
    tokens.add(singleToken.trim());
  }
  if (Array.isArray(tokenList)) {
    tokenList.forEach((item) => {
      const value = typeof item === "string" ? item.trim() : "";
      if (value) tokens.add(value);
    });
  }

  return [...tokens];
}

async function getTutorAuthUid(tutorId) {
  if (!tutorId) return null;

  const tutorDoc = await admin.firestore().collection("tutors").doc(tutorId).get();
  if (!tutorDoc.exists) return null;

  const authUid = tutorDoc.get("authUid");
  if (typeof authUid !== "string" || authUid.trim() === "") return null;

  return authUid;
}

async function removeInvalidToken({userId, token}) {
  if (!userId || !token) return;

  const userRef = admin.firestore().collection("users").doc(userId);
  const updates = {
    fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
  };

  try {
    const userDoc = await userRef.get();
    const current = userDoc.get("fcmToken");
    if (typeof current === "string" && current.trim() === token) {
      updates.fcmToken = admin.firestore.FieldValue.delete();
    }
    await userRef.set(updates, {merge: true});
    logger.warn("Removed invalid FCM token", {userId});
  } catch (error) {
    logger.error("Failed to remove invalid token", {userId, error});
  }
}

async function sendPush({token, title, body, data}) {
  return admin.messaging().send({
    token,
    notification: {
      title,
      body,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "session_updates",
        sound: "default",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
        },
      },
    },
    data: Object.entries(data || {}).reduce((acc, [key, value]) => {
      acc[key] = value == null ? "" : String(value);
      return acc;
    }, {}),
  });
}

async function sendSingleTokenPush({token, title, body, data}) {
  return admin.messaging().send({
    token,
    notification: {
      title,
      body,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "session_updates",
        sound: "default",
      },
    },
    data: Object.entries(data || {}).reduce((acc, [key, value]) => {
      acc[key] = value == null ? "" : String(value);
      return acc;
    }, {}),
  });
}

async function notifyUser({userId, title, body, data, context}) {
  if (!userId) {
    logger.warn("Missing recipient userId", {context});
    return;
  }

  const tokens = await getUserTokens(userId);
  if (tokens.length === 0) {
    logger.warn("No FCM token found for user", {userId, context});
    return;
  }

  await Promise.all(tokens.map(async (token) => {
    try {
      await sendPush({token, title, body, data});
    } catch (error) {
      const code = error?.code || "unknown";
      const isInvalidToken =
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token";

      if (isInvalidToken) {
        await removeInvalidToken({userId, token});
      }

      logger.error("Failed to send push notification", {
        userId,
        context,
        code,
        error,
      });
    }
  }));
}

exports.notifyPaymentStatusChanged = onDocumentUpdated(
  "payments/{paymentId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const oldStatus = String(before.status || "");
    const newStatus = String(after.status || "");

    logger.info("Payment update detected", {
      paymentId: event.params.paymentId,
      oldStatus,
      newStatus,
    });

    if (!newStatus || oldStatus === newStatus) {
      return;
    }

    if (newStatus !== "approved" && newStatus !== "rejected") {
      logger.info("Payment status not in notification list", {
        paymentId: event.params.paymentId,
        newStatus,
      });
      return;
    }

    const studentId = String(after.studentId || "");
    if (!studentId) {
      logger.warn("Missing studentId in payment document", event.params.paymentId);
      return;
    }

    const title = newStatus === "approved" ? "Payment Approved ✅" : "Payment Rejected ❌";
    const body = newStatus === "approved"
      ? "Great news! Your payment was approved and your session is now confirmed."
      : "Your payment was rejected. Please check your payment details and try again.";

    try {
      await notifyUser({
        userId: studentId,
        title,
        body,
        data: {
          type: "payment_status",
          paymentId: event.params.paymentId,
          status: newStatus,
          sessionId: String(after.sessionId || ""),
        },
        context: "notifyPaymentStatusChanged",
      });

      logger.info("Payment status push sent", {
        paymentId: event.params.paymentId,
        studentId,
        status: newStatus,
      });
    } catch (error) {
      logger.error("Failed to send payment notification", {
        paymentId: event.params.paymentId,
        studentId,
        error,
      });
    }
  },
);

async function sendSessionReminderIfDue(sessionId, sessionData) {
  const studentId = String(sessionData.studentId || "").trim();
  if (!studentId) {
    logger.warn("Missing studentId for reminder", {sessionId});
    return;
  }

  const dateTimeRaw = sessionData.dateTime;
  const reminderSentAt = sessionData.reminderSentAt;
  if (reminderSentAt) {
    logger.info("Reminder already sent, skipping", {sessionId});
    return;
  }

  let sessionDate;
  if (dateTimeRaw && typeof dateTimeRaw.toDate === "function") {
    sessionDate = dateTimeRaw.toDate();
  } else if (typeof dateTimeRaw === "string") {
    sessionDate = new Date(dateTimeRaw);
  }

  if (!(sessionDate instanceof Date) || Number.isNaN(sessionDate.getTime())) {
    logger.warn("Invalid session dateTime for reminder", {sessionId, dateTimeRaw});
    return;
  }

  const now = new Date();
  const millisUntilStart = sessionDate.getTime() - now.getTime();
  const oneHourMillis = 60 * 60 * 1000;
  const triggerWindowMillis = 5 * 60 * 1000;

  if (millisUntilStart > oneHourMillis || millisUntilStart < (oneHourMillis - triggerWindowMillis)) {
    logger.info("Session not in reminder window", {
      sessionId,
      millisUntilStart,
    });
    return;
  }

  try {
    const userSnap = await admin.firestore().collection("users").doc(studentId).get();
    const token = String(userSnap.get("fcmToken") || "").trim();
    if (!token) {
      logger.warn("No fcmToken found for session reminder", {sessionId, studentId});
      return;
    }

    await sendSingleTokenPush({
      token,
      title: "Session Reminder ⏰",
      body: "Your tutoring session starts in 1 hour. Get ready!",
      data: {
        type: "session_reminder",
        sessionId,
      },
    });

    await admin.firestore().collection("sessions").doc(sessionId).set({
      reminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    logger.info("Session reminder sent", {sessionId, studentId});
  } catch (error) {
    logger.error("Failed to send session reminder", {sessionId, error});
  }
}

exports.onSessionReminder = onDocumentUpdated("sessions/{sessionId}", async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};

  const oldDate = before.dateTime && typeof before.dateTime.toDate === "function"
    ? before.dateTime.toDate().toISOString()
    : String(before.dateTime || "");
  const newDate = after.dateTime && typeof after.dateTime.toDate === "function"
    ? after.dateTime.toDate().toISOString()
    : String(after.dateTime || "");

  const oldReminderSent = Boolean(before.reminderSentAt);
  const newReminderSent = Boolean(after.reminderSentAt);

  if (oldDate === newDate && oldReminderSent === newReminderSent) {
    return;
  }

  await sendSessionReminderIfDue(event.params.sessionId, after);
});

exports.onSessionReminderCreated = onDocumentCreated("sessions/{sessionId}", async (event) => {
  const data = event.data?.data() || {};
  await sendSessionReminderIfDue(event.params.sessionId, data);
});

exports.notifySessionCreated = onDocumentCreated(
  "sessions/{sessionId}",
  async (event) => {
    const session = event.data?.data() || {};
    const sessionId = event.params.sessionId;

    const studentId = String(session.studentId || "");
    const tutorId = String(session.tutorId || "");
    const tutorAuthUid = await getTutorAuthUid(tutorId);

    const recipients = [
      {
        userId: studentId,
        title: "Session Created",
        body: "Your session has been created successfully.",
      },
      {
        userId: tutorAuthUid,
        title: "New Session",
        body: "You have a new booked session.",
      },
    ];

    await Promise.all(
      recipients.map(async ({userId, title, body}) => {
        if (!userId) return;
        await notifyUser({
          userId,
          title,
          body,
          data: {
            type: "session_created",
            sessionId,
          },
          context: "notifySessionCreated",
        });
      }),
    );
  },
);

exports.notifySessionUpdated = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const oldStatus = String(before.status || "");
    const newStatus = String(after.status || "");

    if (!newStatus || oldStatus === newStatus) {
      logger.info("Session status unchanged or new status empty", {
        sessionId: event.params.sessionId,
        oldStatus,
        newStatus,
      });
      return;
    }

    const sessionId = event.params.sessionId;
    const studentId = String(after.studentId || "");
    const tutorId = String(after.tutorId || "");
    const tutorAuthUid = await getTutorAuthUid(tutorId);

    logger.info("Session status update detected", {
      sessionId,
      oldStatus,
      newStatus,
      studentId,
      tutorId,
      tutorAuthUid,
    });

    if (!["approved", "rejected", "confirmed", "payment_rejected", "completed"].includes(newStatus)) {
      logger.info("Session status not in notification list", {
        sessionId,
        newStatus,
      });
      return;
    }

    const messageByStatus = {
      approved: "Your session has been approved.",
      confirmed: "Your session has been confirmed.",
      rejected: "Your session was rejected.",
      payment_rejected: "Your session payment was rejected.",
      completed: "Your session has been completed.",
    };

    const message = messageByStatus[newStatus] || `Session status updated to ${newStatus}`;

    // Payment approve/reject already pushes to the student via notifyPaymentStatusChanged.
    const studentReceivesPush = !["confirmed", "payment_rejected"].includes(newStatus);
    const recipients = [
      ...(studentReceivesPush && studentId ? [studentId] : []),
      ...(tutorAuthUid ? [tutorAuthUid] : []),
    ];

    logger.info("Preparing to send notifications", {
      sessionId,
      message,
      recipients,
    });

    await Promise.all(
      recipients.map(async (userId) => {
        try {
          await notifyUser({
            userId,
            title: "Session Update",
            body: message,
            data: {
              type: "session_status",
              sessionId,
              status: newStatus,
            },
            context: "notifySessionUpdated",
          });
          logger.info("Notification sent successfully", {
            sessionId,
            userId,
            status: newStatus,
          });
        } catch (error) {
          logger.error("Failed to send notification", {
            sessionId,
            userId,
            status: newStatus,
            error,
          });
        }
      }),
    );
  },
);


