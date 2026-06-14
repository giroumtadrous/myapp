const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const path = require("path");

admin.initializeApp();

function createMeetLink(sessionId) {
  const roomName = `zelp-${sessionId}-${Date.now()}`;
  return `https://meet.jit.si/${roomName}`;
}

exports.onSessionApprovedGenerateMeetLink = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return;
    if (after.status !== "approved") return;
    if (after.meetLink) return;

    const sessionId = event.params.sessionId;

    try {
      const meetLink = createMeetLink(sessionId);

      // Save meet link to session
      await admin.firestore().collection("sessions").doc(sessionId).update({
        meetLink,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Get student and tutor emails
      const studentId = String(after.studentId || "");
      const tutorId = String(after.tutorId || "");
      const subject = String(after.subject || "");
      const dateTime = after.dateTime?.toDate?.() || new Date();
      const dateStr = dateTime.toLocaleString("en-EG", { timeZone: "Africa/Cairo" });

      const [studentDoc, tutorDoc] = await Promise.all([
        admin.firestore().collection("users").doc(studentId).get(),
        admin.firestore().collection("tutors").doc(tutorId).get(),
      ]);

      const studentEmail = studentDoc.get("email") || "";
      const studentName = studentDoc.get("name") || "Student";
      const tutorEmail = tutorDoc.get("email") || "";
      const tutorName = tutorDoc.get("name") || "Tutor";

      logger.info("Email details", { 
  studentEmail, 
  tutorEmail,
  studentId,
  tutorId,
  studentExists: studentDoc.exists,
  tutorExists: tutorDoc.exists,
});

      const emailHtml = (recipientName) => `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #4051B5;">Your Zelp Session is Confirmed! ✅</h2>
          <p>Hi ${recipientName},</p>
          <p>Your tutoring session has been approved. Here are the details:</p>
          <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
            <tr>
              <td style="padding: 8px; color: #64748B;">Subject</td>
              <td style="padding: 8px; font-weight: bold;">${subject}</td>
            </tr>
            <tr>
              <td style="padding: 8px; color: #64748B;">Date & Time</td>
              <td style="padding: 8px; font-weight: bold;">${dateStr}</td>
            </tr>
            <tr>
              <td style="padding: 8px; color: #64748B;">Tutor</td>
              <td style="padding: 8px; font-weight: bold;">${tutorName}</td>
            </tr>
          </table>
          <a href="${meetLink}" 
             style="display: inline-block; background: #4051B5; color: white; 
                    padding: 14px 28px; border-radius: 8px; text-decoration: none; 
                    font-weight: bold; font-size: 16px; margin: 20px 0;">
            Join Session
          </a>
          <p style="color: #64748B; font-size: 12px;">
            Or copy this link: ${meetLink}
          </p>
          <p style="color: #64748B;">See you in the session!<br/>The Zelp Team</p>
        </div>
      `;

      const db = admin.firestore();

      // Send to student
      if (studentEmail) {
        await db.collection("mail").add({
          to: studentEmail,
          message: {
            subject: `Your Zelp session for ${subject} is confirmed!`,
            html: emailHtml(studentName),
          },
        });
      }

      // Send to tutor
      if (tutorEmail) {
        await db.collection("mail").add({
          to: tutorEmail,
          message: {
            subject: `Upcoming Zelp session for ${subject}`,
            html: emailHtml(tutorName),
          },
        });
      }

      logger.info("Session emails sent", { sessionId, studentEmail, tutorEmail });
    } catch (error) {
      logger.error("Failed to generate Meet link", { sessionId, error });
    }
  }
);

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

// ── Feature 1: Student Progress Update ──────────────────────────────────────
exports.onSessionCompletedUpdateProgress = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const oldStatus = String(before.status || "");
    const newStatus = String(after.status || "");

    if (oldStatus === "completed" || newStatus !== "completed") return;

    const sessionId = event.params.sessionId;
    const subject = String(after.subject || "Unknown");
    const tutorId = String(after.tutorId || "");
    const durationMinutes = Number(after.durationMinutes || after.duration || 60);

    // Collect all student IDs from the session
    const studentIds = new Set();
    const singleStudentId = String(after.studentId || "").trim();
    if (singleStudentId) studentIds.add(singleStudentId);
    if (Array.isArray(after.studentIds)) {
      after.studentIds.forEach((id) => {
        const trimmed = String(id || "").trim();
        if (trimmed) studentIds.add(trimmed);
      });
    }

    if (studentIds.size === 0) {
      logger.warn("No students found for progress update", {sessionId});
      return;
    }

    const db = admin.firestore();

    await Promise.all([...studentIds].map(async (studentId) => {
      const progressRef = db
        .collection("students")
        .doc(studentId)
        .collection("progress")
        .doc(subject);

      try {
        await db.runTransaction(async (tx) => {
          const progressDoc = await tx.get(progressRef);

          if (progressDoc.exists) {
            tx.update(progressRef, {
              totalSessions: admin.firestore.FieldValue.increment(1),
              totalMinutes: admin.firestore.FieldValue.increment(durationMinutes),
              lastSessionAt: admin.firestore.FieldValue.serverTimestamp(),
              tutorsUsed: admin.firestore.FieldValue.arrayUnion([tutorId]),
            });
          } else {
            tx.set(progressRef, {
              totalSessions: 1,
              totalMinutes: durationMinutes,
              lastSessionAt: admin.firestore.FieldValue.serverTimestamp(),
              tutorsUsed: tutorId ? [tutorId] : [],
            });
          }
        });
        logger.info("Progress updated", {sessionId, studentId, subject});
      } catch (error) {
        logger.error("Failed to update progress", {sessionId, studentId, subject, error});
      }
    }));
  },
);

// ── Feature 2: Group Session Full Check ─────────────────────────────────────
exports.onGroupSessionStudentJoined = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const sessionType = String(after.type || "solo");
    if (sessionType !== "group") return;

    const beforeStudents = Array.isArray(before.studentIds) ? before.studentIds : [];
    const afterStudents = Array.isArray(after.studentIds) ? after.studentIds : [];

    // Only proceed if a student was added
    if (afterStudents.length <= beforeStudents.length) return;

    const maxStudents = Number(after.maxStudents || 5);
    const currentStudents = afterStudents.length;
    const sessionId = event.params.sessionId;

    const updates = {
      currentStudents: currentStudents,
      pricePerStudent: maxStudents > 0 ? (Number(after.amount || after.hourlyRate || 0)) / maxStudents : 0,
    };

    if (currentStudents >= maxStudents) {
      updates.status = "full";
      logger.info("Group session is now full", {sessionId, currentStudents, maxStudents});
    }

    try {
      await admin.firestore().collection("sessions").doc(sessionId).update(updates);
      logger.info("Group session updated", {sessionId, currentStudents, maxStudents});
    } catch (error) {
      logger.error("Failed to update group session", {sessionId, error});
    }
  },
);

// ── Feature 3: Tutor Earnings on Session Complete ───────────────────────────
exports.onSessionCompletedUpdateEarnings = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const oldStatus = String(before.status || "");
    const newStatus = String(after.status || "");

    if (oldStatus === "completed" || newStatus !== "completed") return;

    const sessionId = event.params.sessionId;
    const tutorId = String(after.tutorId || "").trim();
    if (!tutorId) {
      logger.warn("No tutorId for earnings update", {sessionId});
      return;
    }

    const amount = Number(after.amount || after.hourlyRate || 0);
    const subject = String(after.subject || "");
    const studentId = String(after.studentId || "");

    const db = admin.firestore();
    const walletTxRef = db
      .collection("tutors")
      .doc(tutorId)
      .collection("wallet")
      .doc("transactions")
      .collection("items")
      .doc();

    const walletSummaryRef = db
      .collection("tutors")
      .doc(tutorId)
      .collection("wallet")
      .doc("summary");

    try {
      // Create transaction entry
      await walletTxRef.set({
        sessionId,
        amount,
        status: "pending_payout",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        subject,
        studentId,
      });

      // Update summary
      await walletSummaryRef.set({
        totalEarned: admin.firestore.FieldValue.increment(amount),
        pendingPayout: admin.firestore.FieldValue.increment(amount),
      }, {merge: true});

      logger.info("Earnings updated", {sessionId, tutorId, amount});
    } catch (error) {
      logger.error("Failed to update earnings", {sessionId, tutorId, error});
    }
  },
);

// ── Feature 4: Review Trigger Notification ──────────────────────────────────
exports.onSessionCompletedReviewReminder = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const oldStatus = String(before.status || "");
    const newStatus = String(after.status || "");

    if (oldStatus === "completed" || newStatus !== "completed") return;

    const sessionId = event.params.sessionId;
    const tutorId = String(after.tutorId || "").trim();
    const subject = String(after.subject || "");

    // Collect student IDs
    const studentIds = new Set();
    const singleStudentId = String(after.studentId || "").trim();
    if (singleStudentId) studentIds.add(singleStudentId);
    if (Array.isArray(after.studentIds)) {
      after.studentIds.forEach((id) => {
        const trimmed = String(id || "").trim();
        if (trimmed) studentIds.add(trimmed);
      });
    }

    if (studentIds.size === 0) return;

    // Wait 5 minutes before sending review reminder
    setTimeout(async () => {
      try {
        // Get tutor name
        let tutorName = "your tutor";
        if (tutorId) {
          const tutorDoc = await admin.firestore().collection("tutors").doc(tutorId).get();
          if (tutorDoc.exists) {
            tutorName = String(tutorDoc.get("name") || "your tutor");
          }
        }

        const title = "How was your session?";
        const body = `Rate your session with ${tutorName} in ${subject}`;

        await Promise.all([...studentIds].map(async (studentId) => {
          // Send FCM push
          await notifyUser({
            userId: studentId,
            title,
            body,
            data: {
              type: "review_request",
              sessionId,
            },
            context: "onSessionCompletedReviewReminder",
          });

          // Create in-app notification
          const notifId = `${studentId}_review_${sessionId}`;
          await admin.firestore().collection("notifications").doc(notifId).set({
            userId: studentId,
            title,
            message: body,
            read: false,
            type: "review_request",
            sessionId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          logger.info("Review reminder sent", {sessionId, studentId});
        }));
      } catch (error) {
        logger.error("Failed to send review reminders", {sessionId, error});
      }
    }, 5 * 60 * 1000); // 5 minutes
  },
);

// ── Feature 5: SOS Request — Notify Tutors ──────────────────────────────────
exports.onSosRequestCreatedNotifyTutors = onDocumentCreated(
  "sos_requests/{requestId}",
  async (event) => {
    const data = event.data?.data() || {};
    const requestId = event.params.requestId;
    const subject = String(data.subject || "");
    const studentId = String(data.studentId || "");

    if (!subject) {
      logger.warn("SOS request missing subject", {requestId});
      return;
    }

    try {
      // Query tutors available for SOS
      const tutorsSnap = await admin.firestore()
        .collection("tutors")
        .where("isAvailableForSOS", "==", true)
        .get();

      const matchingTutors = tutorsSnap.docs.filter((doc) => {
        const tutorData = doc.data();
        const subjects = Array.isArray(tutorData.subjects) ? tutorData.subjects : [];
        return subjects.some((s) =>
          String(s).toLowerCase() === subject.toLowerCase()
        );
      });

      logger.info("SOS: found matching tutors", {
        requestId,
        subject,
        count: matchingTutors.length,
      });

      await Promise.all(matchingTutors.map(async (tutorDoc) => {
        const tutorAuthUid = await getTutorAuthUid(tutorDoc.id);
        if (!tutorAuthUid) return;

        await notifyUser({
          userId: tutorAuthUid,
          title: "SOS Request! 🆘",
          body: `A student needs help with ${subject} right now`,
          data: {
            type: "sos_request",
            sosRequestId: requestId,
            subject: subject,
          },
          context: "onSosRequestCreatedNotifyTutors",
        });
      }));
    } catch (error) {
      logger.error("Failed to notify tutors for SOS", {requestId, error});
    }
  },
);

// ── Feature 5: SOS Request — Expiry ─────────────────────────────────────────
exports.onSosRequestCreatedExpiry = onDocumentCreated(
  "sos_requests/{requestId}",
  async (event) => {
    const data = event.data?.data() || {};
    const requestId = event.params.requestId;
    const studentId = String(data.studentId || "").trim();

    // Schedule expiry after 1 hour
    setTimeout(async () => {
      try {
        const db = admin.firestore();
        const requestRef = db.collection("sos_requests").doc(requestId);
        const requestDoc = await requestRef.get();

        if (!requestDoc.exists) return;

        const currentStatus = String(requestDoc.get("status") || "");
        if (currentStatus !== "searching") {
          logger.info("SOS request already resolved, skipping expiry", {
            requestId,
            currentStatus,
          });
          return;
        }

        // Mark as failed
        await requestRef.update({
          status: "failed",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Notify student
        if (studentId) {
          await notifyUser({
            userId: studentId,
            title: "SOS Request Expired",
            body: "No tutor was available for your request. Try again later.",
            data: {
              type: "sos_expired",
              sosRequestId: requestId,
            },
            context: "onSosRequestCreatedExpiry",
          });

          // Create in-app notification
          const notifId = `${studentId}_sos_expired_${requestId}`;
          await db.collection("notifications").doc(notifId).set({
            userId: studentId,
            title: "SOS Request Expired",
            message: "No tutor was available for your request. Try again later.",
            read: false,
            type: "sos_expired",
            sosRequestId: requestId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        logger.info("SOS request expired", {requestId});
      } catch (error) {
        logger.error("Failed to expire SOS request", {requestId, error});
      }
    }, 60 * 60 * 1000); // 1 hour
  },
);
