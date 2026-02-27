const { onDocumentUpdated, onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
require("dotenv").config();
const BRAND_BLUE = "#1A237E";
const BRAND_BLUE_LIGHT = "#EBF5FF";

admin.initializeApp();

/**
 * Converts a number into words (Indian Numbering System)
 */
function numberToWords(num) {
    const a = ['', 'One ', 'Two ', 'Three ', 'Four ', 'Five ', 'Six ', 'Seven ', 'Eight ', 'Nine ', 'Ten ', 'Eleven ', 'Twelve ', 'Thirteen ', 'Fourteen ', 'Fifteen ', 'Sixteen ', 'Seventeen ', 'Eighteen ', 'Nineteen '];
    const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    const inWords = (n) => {
        if (n < 20) return a[n];
        if (n < 100) return b[Math.floor(n / 10)] + (n % 10 !== 0 ? ' ' + a[n % 10] : '');
        if (n < 1000) return a[Math.floor(n / 100)] + 'Hundred ' + (n % 100 !== 0 ? 'and ' + inWords(n % 100) : '');
        if (n < 100000) return inWords(Math.floor(n / 1000)) + 'Thousand ' + (n % 1000 !== 0 ? inWords(n % 1000) : '');
        if (n < 10000000) return inWords(Math.floor(n / 100000)) + 'Lakh ' + (n % 100000 !== 0 ? inWords(n % 100000) : '');
        return inWords(Math.floor(n / 10000000)) + 'Crore ' + (n % 10000000 !== 0 ? inWords(n % 10000000) : '');
    };

    const whole = Math.floor(num);
    const fraction = Math.round((num - whole) * 100);

    let result = inWords(whole) + 'Only';
    if (fraction > 0) {
        result = inWords(whole) + 'and ' + inWords(fraction) + 'Paise Only';
    }
    return result.trim();
}

/**
 * Sends a notification to a specific user based on their role and ID.
 **/

async function sendNotification(tenantId, appId, role, userId, payload) {
    if (!userId) {
        console.error(`[ERROR] Skipping notification: Missing userId for role ${role}`);
        return;
    }

    try {
        const path = `${tenantId}/${appId}/notifications_tokens/${role}/tokens/${userId}`;
        console.log(`[DEBUG] Token lookup for ${role}: ${path}`);

        const tokenDoc = await admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("notifications_tokens")
            .doc(role)
            .collection("tokens")
            .doc(userId)
            .get();

        if (!tokenDoc.exists) {
            console.warn(`[WARN] No token found at path: ${path}`);
            return;
        }

        const data = tokenDoc.data();
        if (!data || !data.token) {
            console.warn(`[WARN] Token field missing in doc for ${userId}`);
            return;
        }

        const registrationToken = data.token;
        console.log(`[DEBUG] Found token for ${userId}: ${registrationToken.substring(0, 10)}...`);

        const message = {
            token: registrationToken,
            notification: payload.notification,
            data: payload.data || {},
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel",
                    priority: "high",
                    defaultSound: true,
                },
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        sound: "default",
                    },
                },
            },
        };

        try {
            const response = await admin.messaging().send(message);
            console.log(`[SUCCESS] Notification sent to ${userId} (${role}). Response: ${response}`);
        } catch (fcmError) {
            console.error(`[FCM ERROR] Failed to send to ${userId}:`, fcmError);
        }
    } catch (error) {
        console.error(`[SYSTEM ERROR] sendNotification failed:`, error);
    }
}

// 1. HTTP Test Function: Send notification to any user
// Usage: https://<region>-<project>.cloudfunctions.net/testNotify?tenantId=white-label-app-33300&appId=data&role=engineer&userId=JohnDoe
exports.testNotify = onRequest(async (req, res) => {
    const { tenantId, appId, role, userId } = req.query;
    if (!tenantId || !appId || !role || !userId) {
        return res.status(400).send("Missing query params: tenantId, appId, role, userId");
    }

    const payload = {
        notification: {
            title: "Test Notification",
            body: `This is a test notification from Cloud Functions for ${userId}`,
        },
        data: {
            type: "test",
            sender: "system",
        },
    };

    console.log(`[HTTP TEST] Triggered for ${userId} in ${tenantId}/${appId}`);
    await sendNotification(tenantId, appId, role, userId, payload);
    res.send(`Attempted to send notification to ${userId}. Check functions logs for results.`);
});


// 3. Notify Admin when a new ticket is raised
exports.handleTicketCreation = onDocumentCreated("{tenantId}/{appId}/Admin_details/{bookingId}", async (event) => {
    const ticketData = event.data.data();
    const { tenantId, appId, bookingId } = event.params;
    console.log(`[DEBUG] New ticket raised in ${tenantId}/${appId}: ${bookingId}`);

    try {
        const adminsSnapshot = await admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("notifications_tokens")
            .doc("admin")
            .collection("tokens")
            .get();

        if (adminsSnapshot.empty) {
            console.log("[DEBUG] No admins found to notify");
            return;
        }

        const payload = {
            notification: {
                title: "New Ticket Raised",
                body: `A new ticket (${bookingId}) has been raised by ${ticketData.customerName || "a customer"}`,
            },
            data: {
                type: "new_ticket",
                bookingId: bookingId || "",
            },
        };

        const promises = adminsSnapshot.docs.map((doc) => {
            const data = doc.data();
            if (!data || !data.token) return Promise.resolve();

            const message = {
                token: data.token,
                notification: payload.notification,
                data: payload.data,
                android: {
                    priority: "high",
                    notification: {
                        channelId: "high_importance_channel",
                        priority: "high",
                        defaultSound: true,
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            contentAvailable: true,
                            sound: "default",
                        },
                    },
                },
            };
            return admin.messaging().send(message).catch(error => {
                console.error(`[FCM ERROR] Failed to notify admin ${doc.id}:`, error);
                return null;
            });
        });

        await Promise.all(promises);
        console.log(`[SUCCESS] Notified ${adminsSnapshot.size} admin devices`);
    } catch (e) {
        console.error("[SYSTEM ERROR] onTicketRaised failed:", e);
    }
});

// 4. Notify Customer when ticket status is updated
exports.handleTicketStatusUpdate = onDocumentUpdated("{tenantId}/{appId}/Admin_details/{bookingId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    const { tenantId, appId, bookingId } = event.params;

    // ── Engineer Assignment Notification ────────────────────────────────
    const isNewAssignment = newData.assignedEmployee &&
        newData.assignedEmployee !== oldData.assignedEmployee;

    if (isNewAssignment) {
        console.log(`[DEBUG] Assignment detected in ${tenantId}/${appId} for ${bookingId}. Engineer: ${newData.assignedEmployee}`);

        // 1. Notify Engineer via FCM push
        const engineerPayload = {
            notification: {
                title: "New Assignment",
                body: `You have been assigned a new task: ${bookingId}`,
            },
            data: {
                type: "new_assignment",
                bookingId: bookingId,
            },
        };
        const engineerId = newData.assignedEmployee.trim();
        await sendNotification(tenantId, appId, "engineer", engineerId, engineerPayload);

        // 2. Notify Customer
        if (newData.id) {
            const customerPayload = {
                notification: {
                    title: "Ticket Assigned",
                    body: `Your ticket (${bookingId}) has been assigned to ${newData.assignedEmployee}`,
                },
                data: {
                    type: "ticket_assigned",
                    bookingId: bookingId,
                    engineerName: newData.assignedEmployee,
                },
            };
            await sendNotification(tenantId, appId, "customer", newData.id, customerPayload);

            // Also create an in-app notification document for the customer banner
            await admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("notifications")
                .add({
                    customerId: newData.id,
                    customerName: newData.customerName || "",
                    bookingId: bookingId,
                    title: "Ticket Assigned",
                    body: `Your ticket (${bookingId}) has been assigned to ${newData.assignedEmployee}`,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    seen: false,
                    type: "ticket_assigned"
                });
        }
    }

    // ── Status Change Notification ──────────────────────────────────────
    const statusChanged = (newData.engineerStatus !== oldData.engineerStatus) ||
        (newData.adminStatus !== oldData.adminStatus);

    if (statusChanged) {
        const currentStatus = newData.engineerStatus || newData.adminStatus || "Updated";
        console.log(`[DEBUG] Status update in ${tenantId}/${appId} for ${bookingId}: ${currentStatus}`);

        const payload = {
            notification: {
                title: "Ticket Update",
                body: `Your ticket (${bookingId}) status is now: ${currentStatus}`,
            },
            data: {
                type: "status_update",
                bookingId: bookingId,
                status: currentStatus,
            },
        };

        // 1. Notify Customer
        if (newData.id) {
            await sendNotification(tenantId, appId, "customer", newData.id, payload);

            // Also create an in-app notification document for the banner
            await admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("notifications")
                .add({
                    customerId: newData.id,
                    customerName: newData.customerName || "",
                    bookingId: bookingId,
                    title: "Ticket Update",
                    body: `Your ticket (${bookingId}) status is now: ${currentStatus}`,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    seen: false,
                    type: "status_update"
                });
        }

        // 2. Notify Admins if engineerStatus changed
        if (newData.engineerStatus !== oldData.engineerStatus) {
            console.log(`[DEBUG] Engineer status update detected for ${bookingId}. Notifying admins.`);
            const adminPayload = {
                notification: {
                    title: "Engineer Job Update",
                    body: `Engineer ${newData.assignedEmployee || "An engineer"} updated ticket ${bookingId} to: ${newData.engineerStatus}`,
                },
                data: {
                    type: "engineer_status_update",
                    bookingId: bookingId,
                    status: newData.engineerStatus,
                    engineerName: newData.assignedEmployee || "",
                },
            };

            const adminsSnapshot = await admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("notifications_tokens")
                .doc("admin")
                .collection("tokens")
                .get();

            if (!adminsSnapshot.empty) {
                const adminPromises = adminsSnapshot.docs.map(doc => {
                    const data = doc.data();
                    if (!data || !data.token) return null;
                    return sendNotification(tenantId, appId, "admin", doc.id, adminPayload);
                });
                await Promise.all(adminPromises);
                console.log(`[SUCCESS] Notified ${adminsSnapshot.size} admins about engineer status update.`);
            }
        }
    }
});

// 4. Send Email via Nodemailer when a document is created in the "mail" collection
exports.processMailDocument = onDocumentCreated("mail/{docId}", async (event) => {
    const data = event.data.data();
    if (!data || !data.to) {
        console.error("[EMAIL] Skipping: Missing 'to' field.");
        return;
    }

    const nodemailer = require("nodemailer");

    // ─────────────────────────────────────────────────────────────────────────
    // ACTION REQUIRED: Replace YOUR_GMAIL_APP_PASSWORD with your Gmail App
    // Password. Generate one at:
    //   myaccount.google.com → Security → 2-Step Verification → App Passwords
    // For production, store this in Firebase Secret Manager:
    //   firebase functions:secrets:set GMAIL_APP_PASSWORD
    // ─────────────────────────────────────────────────────────────────────────
    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST || "smtp.hostinger.com",
        port: parseInt(process.env.SMTP_PORT || "465"),
        secure: true,
        auth: {
            user: process.env.SMTP_USER || "support@rookstechnologies.com",
            pass: process.env.SMTP_PASS || "Rooks!123",
        },
    });

    console.log(`[EMAIL] Attempting to send using ${process.env.SMTP_USER || "support@rookstechnologies.com"}`);

    const mailOptions = {
        from: `"${process.env.COMPANY_NAME || "Rooks And Brooks"}" <${process.env.SMTP_USER || "support@rookstechnologies.com"}>`,
        to: data.to,
        subject: data.message.subject,
        html: data.message.html,
        attachments: (data.message.attachments || []).map((att) => ({
            filename: att.filename,
            content: att.content,
            encoding: "base64",
            contentType: att.contentType, // Added contentType for better attachment handling
        })),
    };

    try {
        console.log(`[EMAIL] Sending to ${data.to} | Subject: "${data.message.subject}"`);
        await transporter.sendMail(mailOptions);
        console.log(`[EMAIL] Successfully sent to ${data.to}`);

        return event.data.ref.update({
            status: { state: "SENT", sentAt: admin.firestore.FieldValue.serverTimestamp() },
        });
    } catch (error) {
        console.error(`[EMAIL ERROR] Failed to send to ${data.to}:`, error.message);
        return event.data.ref.update({
            status: {
                state: "ERROR",
                error: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
        });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Generate Professional PDF Receipt & Send Email on Payment Success
//    Trigger: {tenantId}/{appId}/payment_transactions/{txnId} → status = SUCCESS
// ─────────────────────────────────────────────────────────────────────────────
exports.processPaymentSuccess = onDocumentWritten(
    "{tenantId}/{appId}/payment_transactions/{txnId}",
    async (event) => {
        const newData = event.data.after ? event.data.after.data() : null;
        const oldData = event.data.before ? event.data.before.data() : null;
        const { tenantId, appId, txnId } = event.params;

        if (!newData || newData.status !== "SUCCESS") return;

        // Only fire when status transitions TO "SUCCESS" (not on subsequent edits)
        const wasAlreadySuccess = oldData && oldData.status === "SUCCESS";
        if (wasAlreadySuccess) return;

        const now = new Date();
        // Invoice number: INV-YYYYMMDD-XXXXXX (last 6 chars of txnId, uppercased)
        const invoiceNo = `INV-${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}-${txnId.slice(-6).toUpperCase()}`;
        const formattedDate = now.toLocaleDateString("en-IN", { day: "2-digit", month: "long", year: "numeric" });
        const formattedTime = now.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });

        console.log(`[RECEIPT] Triggered for txn=${txnId} | invoice=${invoiceNo} | tenant=${tenantId}/${appId}`);

        try {
            // ── 1. Validate required transaction fields ─────────────────────
            const uid = newData.uid;
            if (!uid) {
                console.error(`[ERROR] Missing uid in transaction ${txnId}`);
                return;
            }

            // ── 2. Fetch User from Firestore ────────────────────────────────
            let recipientEmail = null;
            let userName = "Valued Customer";

            // Primary lookup: {tenantId}/data/users/{uid}
            const userDoc = await admin.firestore()
                .collection(tenantId).doc("data")
                .collection("users").doc(uid).get();

            if (userDoc.exists) {
                const ud = userDoc.data();
                recipientEmail = ud.email || null;
                userName = ud.name || ud.displayName || ud.fullName || "Valued Customer";
            }

            // Fallback: Firebase Auth
            if (!recipientEmail) {
                try {
                    const authUser = await admin.auth().getUser(uid);
                    recipientEmail = authUser.email || null;
                    if (!userName || userName === "Valued Customer") {
                        userName = authUser.displayName || "Valued Customer";
                    }
                } catch (authErr) {
                    console.warn(`[WARN] Auth lookup failed for uid ${uid}:`, authErr.message);
                }
            }

            if (!recipientEmail) {
                console.error(`[ERROR] No email found for uid ${uid}. Cannot send receipt.`);
                return;
            }
            console.log(`[RECEIPT] Sending receipt to: ${recipientEmail} (${userName})`);

            // ── 3. Calculate GST (18%) ──────────────────────────────────────
            const totalAmount = parseFloat(newData.amount) || 0;
            const GST_RATE = 0.18;
            const baseAmount = parseFloat((totalAmount / (1 + GST_RATE)).toFixed(2));
            const gstAmount = parseFloat((totalAmount - baseAmount).toFixed(2));
            const planName = newData.planName || "Subscription Plan";
            const billingCycle = newData.isYearly ? "Yearly" : "Monthly";
            const paymentMethod = newData.paymentMethod || "Online";
            const transactionId = newData.merchantTxnNo || newData.paymentId || txnId;

            // ── 4. Calculate Subscription Dates for PDF ───────────────────
            const startD = new Date();
            const endD = new Date();
            if (newData.isYearly) {
                endD.setFullYear(endD.getFullYear() + 1);
            } else if (newData.isSixMonths) {
                endD.setMonth(endD.getMonth() + 6);
            } else {
                endD.setMonth(endD.getMonth() + 1);
            }
            const fmtStart = startD.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
            const fmtEnd = endD.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });

            // ── 5. Generate Professional PDF ───────────────────────────────
            const PDFDocument = require("pdfkit");
            const BRAND_COLOR = BRAND_BLUE;
            const LIGHT_BG = "#F9FAFB";
            const TEXT_DARK = "#515861ff";
            const TEXT_MID = "#4B5563";
            const COMPANY_NAME = process.env.COMPANY_NAME || "Rooks And Brooks";
            const COMPANY_EMAIL = process.env.COMPANY_EMAIL || "support@rookstechnologies.com";
            const COMPANY_GSTIN = process.env.COMPANY_GSTIN || "GSTIN: 33AAMCR8640J1ZZ";

            const generatePdfBuffer = () => new Promise((resolve, reject) => {
                const doc = new PDFDocument({ margin: 40, size: "A4" });
                const buffers = [];
                doc.on("data", (chunk) => buffers.push(chunk));
                doc.on("end", () => resolve(Buffer.concat(buffers)));
                doc.on("error", reject);

                const W = doc.page.width;
                const L = 50;
                const R = W - 50;
                const contentW = R - L;
                const ACCENT_BLUE = "#163A70";
                const DIVIDER_GREY = "#E5E7EB";
                const LABEL_COLOR = "#6B7280";
                const VALUE_COLOR = "#111827";

                // ── Header Section ──────────────────────────────────────────
                // Logo & Company Name
                try {
                    doc.image("assets/logo.png", L, 30, { height: 40 });
                } catch (e) {
                    console.warn("[PDF] Image missing:", e.message);
                }
                doc.font("Helvetica-Bold").fontSize(18).fillColor(ACCENT_BLUE).text("ROOKS & BROOKS", L + 55, 42);

                // Centered "INVOICE" Title
                doc.font("Helvetica-Bold").fontSize(14).fillColor(ACCENT_BLUE).text("INVOICE", 0, 85, { width: W, align: "center" });

                // Top Border Detail Line
                doc.moveTo(L, 110).lineTo(R, 110).lineWidth(1).strokeColor(ACCENT_BLUE).stroke();

                // ── Customer & Invoice Details ──────────────────────────────
                let y = 140;
                const colW = contentW / 2;
                const labelOffset = 110; // Increased offset for labels

                const drawField = (label, value, x, currentY, isBold = true) => {
                    doc.font("Helvetica").fontSize(10).fillColor(LABEL_COLOR).text(label, x, currentY);
                    doc.font(isBold ? "Helvetica-Bold" : "Helvetica").fontSize(10).fillColor(VALUE_COLOR).text(value, x + labelOffset, currentY, { width: colW - labelOffset });
                    return currentY + 30;
                };

                // Left Column
                let leftY = y;
                leftY = drawField("Invoice to", userName, L, leftY);
                // Secondary Email line for Invoice to
                doc.font("Helvetica").fontSize(9).fillColor(LABEL_COLOR).text(recipientEmail, L + labelOffset, leftY - 18);
                leftY += 15;
                leftY = drawField("Document", "INV", L, leftY);
                leftY = drawField("Invoice No", invoiceNo, L, leftY);
                leftY = drawField("Date of Invoice", formattedDate, L, leftY);

                // Right Column
                let rightY = y;
                const rightX = L + colW + 10;
                rightY = drawField("GSTIN", "33AAMCR8640J1ZZ", rightX, rightY);
                rightY = drawField("Subscription", `${planName} (${billingCycle})`, rightX, rightY);
                rightY = drawField("Subscription Period", `${fmtStart} – ${fmtEnd}`, rightX, rightY);
                rightY = drawField("Payment Method", paymentMethod, rightX, rightY);
                rightY = drawField("Transaction ID", transactionId, rightX, rightY);

                // ── Table Section ───────────────────────────────────────────
                y = Math.max(leftY, rightY) + 20;
                const tableHeaderH = 30;
                const col = {
                    desc: L,
                    qty: L + 190,
                    price: L + 245,
                    gst: L + 340,
                    total: L + 410
                };

                // Table Header
                doc.rect(L, y, contentW, tableHeaderH).fill(ACCENT_BLUE);
                doc.font("Helvetica-Bold").fontSize(10).fillColor("#FFFFFF");
                doc.text("Description", col.desc + 10, y + 10);
                doc.text("Qty", col.qty, y + 10, { width: 40, align: "center" });
                doc.text("Unit Price", col.price, y + 10, { width: 80, align: "right" });
                doc.text("GST %", col.gst, y + 10, { width: 50, align: "center" });
                doc.text("Total", col.total, y + 10, { width: 85, align: "right" });

                // Data row
                y += tableHeaderH;
                doc.rect(L, y, contentW, 40).fill("#F3F4F6");
                doc.font("Helvetica").fontSize(10).fillColor(VALUE_COLOR);
                doc.text(planName, col.desc + 10, y + 15, { width: 170 });
                doc.text("1", col.qty, y + 15, { width: 40, align: "center" });
                doc.text(baseAmount.toFixed(2), col.price, y + 15, { width: 80, align: "right" });
                doc.text("18", col.gst, y + 15, { width: 50, align: "center" });
                doc.text(`${totalAmount.toFixed(2)}`, col.total, y + 15, { width: 85, align: "right" });

                // ── Summary Section ─────────────────────────────────────────
                y += 60;
                const summaryW = 220;
                const summaryH = 40;
                doc.rect(R - summaryW, y, summaryW, summaryH).fill(ACCENT_BLUE);
                doc.font("Helvetica-Bold").fontSize(11).fillColor("#FFFFFF");
                doc.text("Invoice Total", R - summaryW + 15, y + 15);
                doc.text(`${totalAmount.toFixed(2)}`, R - summaryW, y + 15, { width: summaryW - 15, align: "right" });

                // ── Footer Section ──────────────────────────────────────────
                // Border line before footer
                y += 100;
                doc.moveTo(L, y).lineTo(R, y).lineWidth(0.5).strokeColor("#D1D5DB").stroke();
                y += 15;

                // Total in words
                doc.font("Helvetica").fontSize(10).fillColor(LABEL_COLOR).text("Invoice total in words", L, y);
                doc.font("Helvetica-Bold").fontSize(10).fillColor(VALUE_COLOR).text(`${numberToWords(totalAmount)} Only`, L + 280, y, { width: contentW - 280, align: "right" });

                // Signature section
                y += 50;
                doc.font("Helvetica").fontSize(10).fillColor(LABEL_COLOR).text("Authorized Signature", L, y);
                doc.font("Helvetica").fontSize(8).fillColor(LABEL_COLOR).text("Digitally signed by Rooks & Brooks Technologies", R - 250, y, { width: 250, align: "right" });
                doc.font("Helvetica").fontSize(8).fillColor("#9CA3AF").text(formattedDate, R - 250, y + 12, { width: 250, align: "right" });

                // Divider line
                y += 40;
                doc.moveTo(L, y).lineTo(R, y).lineWidth(0.5).strokeColor("#D1D5DB").stroke();

                // Bottom contact details
                const footerY = doc.page.height - 80;
                doc.font("Helvetica").fontSize(9).fillColor(LABEL_COLOR);
                doc.text("No: 17, Jawahar Street, Ramavarmapuram, Nagercoil, 629001.", 0, footerY, { width: W, align: "center" });
                doc.text(`${COMPANY_EMAIL}    |    +91 7598707071`, 0, footerY + 15, { width: W, align: "center" });

                doc.end();
            });

            const pdfBuffer = await generatePdfBuffer();
            const pdfBase64 = pdfBuffer.toString("base64");

            // ── 5. Build Branded HTML Email ────────────────────────────────
            const htmlEmail = `
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Payment Receipt</title></head>
<body style="margin:0;padding:0;background-color:#F4F6F9;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F9;padding:30px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">

        <!-- Header -->
        <tr>
          <td style="background:#1A237E;padding:32px 40px;">
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td><span style="font-size:22px;font-weight:700;color:#ffffff;">${COMPANY_NAME}</span></td>
                <td align="right"><span style="font-size:28px;font-weight:800;color:#ffffff;letter-spacing:2px;">RECEIPT</span></td>
              </tr>
              <tr>
                <td><span style="font-size:12px;color:#BBDEFB;">${COMPANY_EMAIL}</span></td>
                <td align="right"><span style="font-size:11px;color:#BBDEFB;">${invoiceNo}</span></td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Greeting -->
        <tr>
          <td style="padding:32px 40px 0;">
            <p style="font-size:16px;color:#212121;margin:0 0 8px;">Hello, <strong>${userName}</strong>!</p>
            <p style="font-size:14px;color:#616161;margin:0 0 24px;line-height:1.6;">
              Your subscription payment was <strong style="color:${BRAND_BLUE};">successful</strong>.
              Please find your official invoice attached to this email as a PDF.
            </p>
          </td>
        </tr>

        <!-- Summary Card -->
        <tr>
          <td style="padding:0 40px;">
            <table width="100%" cellpadding="12" cellspacing="0"
              style="background:#F5F5F5;border-radius:8px;font-size:13px;color:#424242;">
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Invoice No</strong></td>
                <td align="right">${invoiceNo}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Date</strong></td>
                <td align="right">${formattedDate} at ${formattedTime}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Plan</strong></td>
                <td align="right">${planName} (${billingCycle})</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Transaction ID</strong></td>
                <td align="right" style="font-size:11px;word-break:break-all;">${transactionId}</td>
              </tr>
              <tr style="border-bottom:1px solid #E0E0E0;">
                <td><strong>Payment Method</strong></td>
                <td align="right">${paymentMethod}</td>
              </tr>
              <tr style="border-bottom:0.5px solid #E0E0E0;">
                <td><strong>Subtotal (ex-GST)</strong></td>
                <td align="right">₹${baseAmount.toFixed(2)}</td>
              </tr>
              <tr style="border-bottom:0.5px solid #E0E0E0;">
                <td><strong>GST (18%)</strong></td>
                <td align="right">₹${gstAmount.toFixed(2)}</td>
              </tr>
              <tr style="background:#1A237E;border-radius:4px;">
                <td style="color:#fff;font-size:15px;border-radius:4px 0 0 4px;"><strong>Total Paid</strong></td>
                <td align="right" style="color:#fff;font-size:17px;font-weight:700;border-radius:0 4px 4px 0;">
                  ₹${totalAmount.toFixed(2)}
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Attachment note -->
        <tr>
          <td style="padding:24px 40px 0;">
            <p style="font-size:13px;color:#616161;margin:0;">
              📎 A detailed <strong>PDF invoice</strong> is attached to this email for your records.
            </p>
          </td>
        </tr>

        <!-- CTA -->
        <tr>
          <td style="padding:28px 40px 0;" align="center">
            <span style="display:inline-block;background:#1A237E;color:#fff;font-size:14px;font-weight:600;
              padding:12px 32px;border-radius:6px;text-decoration:none;">
              ✓ &nbsp; Subscription Active
            </span>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:32px 40px;border-top:1px solid #E0E0E0;margin-top:28px;">
            <p style="font-size:12px;color:#9E9E9E;text-align:center;margin:0;">
              ${COMPANY_NAME} &nbsp;|&nbsp; ${COMPANY_EMAIL}<br>
              This is an automatically generated email. Please do not reply to this message.<br>
              © ${now.getFullYear()} ${COMPANY_NAME}. All rights reserved.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;

            // ── 6. Write to 'mail' collection → triggers processMailDocument ──
            await admin.firestore().collection("mail").add({
                to: recipientEmail,
                message: {
                    subject: `Payment Confirmed — ${planName} | ${invoiceNo}`,
                    html: htmlEmail,
                    attachments: [{
                        filename: `Invoice_${invoiceNo}.pdf`,
                        content: pdfBase64,
                        encoding: "base64",
                    }],
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                txnId: txnId,
                invoiceNo: invoiceNo,
                uid: uid,
            });

            console.log(`[RECEIPT] ✅ Email queued for ${recipientEmail} | invoice=${invoiceNo}`);

            // ── 7. Update transaction doc with invoice details ──────────────
            await event.data.after.ref.update({
                invoiceNo: invoiceNo,
                receiptSentAt: admin.firestore.FieldValue.serverTimestamp(),
                receiptEmail: recipientEmail,
            });

            // ── 8. Update Subscription Dates & Lifecycle ────────────────
            // Calculate expiry based on billing cycle
            const expiryDate = new Date();
            if (newData.isYearly) {
                expiryDate.setFullYear(expiryDate.getFullYear() + 1);
            } else if (newData.isSixMonths) {
                expiryDate.setMonth(expiryDate.getMonth() + 6);
            } else {
                expiryDate.setMonth(expiryDate.getMonth() + 1);
            }

            const subscriptionRef = admin.firestore()
                .collection(tenantId)
                .doc(appId)
                .collection("subscriptions")
                .doc(uid);

            await subscriptionRef.set({
                status: "active",
                planName: planName,
                isYearly: newData.isYearly || false,
                isSixMonths: newData.isSixMonths || false,
                price: totalAmount,
                startedAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: admin.firestore.Timestamp.fromDate(expiryDate),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                reminderSent: false, // Reset for new period
                corporateEmail: recipientEmail,
            }, { merge: true });

            console.log(`[LIFECYCLE] Updated subscription for ${uid} | expires=${expiryDate.toISOString()}`);

        } catch (error) {
            console.error(`[RECEIPT ERROR] processPaymentSuccess failed for ${txnId}:`, error);
        }
    });

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * OTP & Password Reset Logic
 * ─────────────────────────────────────────────────────────────────────────────
 */

// 7. Send OTP for Forgot Password
exports.sendOTP = onRequest(async (req, res) => {
    // Handle CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.set('Access-Control-Max-Age', '3600');
        return res.status(204).send('');
    }

    const data = req.body.data;
    if (!data || !data.email) {
        return res.status(400).send({ data: { success: false, message: "Missing email parameter" } });
    }

    const email = data.email.trim().toLowerCase();
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes from now

    try {
        // Store OTP in Firestore
        await admin.firestore().collection("otps").doc(email).set({
            otp,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Send Email
        const nodemailer = require("nodemailer");
        const transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST || "smtp.hostinger.com",
            port: parseInt(process.env.SMTP_PORT || "465"),
            secure: true,
            auth: {
                user: process.env.SMTP_USER || "support@rookstechnologies.com",
                pass: process.env.SMTP_PASS || "Rooks!123",
            },
        });

        const mailOptions = {
            from: `"${process.env.COMPANY_NAME || "Rooks And Brooks"}" <${process.env.SMTP_USER || "support@rookstechnologies.com"}>`,
            to: email,
            subject: "Your Password Reset OTP",
            html: `
                <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                    <h2>Password Reset Request</h2>
                    <p>You requested to reset your password. Use the following OTP to proceed:</p>
                    <div style="font-size: 24px; font-weight: bold; padding: 10px; background: #f4f4f4; display: inline-block; letter-spacing: 5px;">
                        ${otp}
                    </div>
                    <p>This code will expire in 10 minutes.</p>
                    <p>If you didn't request this, please ignore this email.</p>
                    <br>
                    <p>Regards,<br>${process.env.COMPANY_NAME || "Rooks And Brooks"}</p>
                </div>
            `
        };

        await transporter.sendMail(mailOptions);
        console.log(`[OTP] Sent to ${email}`);
        res.send({ data: { success: true, message: "OTP sent successfully" } });

    } catch (error) {
        console.error(`[OTP ERROR] Failed to send for ${email}:`, error);
        res.status(500).send({ data: { success: false, message: error.message } });
    }
});

// 8. Verify OTP and Reset Password
exports.verifyOTPAndResetPassword = onRequest(async (req, res) => {
    // Handle CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.set('Access-Control-Max-Age', '3600');
        return res.status(204).send('');
    }

    const data = req.body.data;
    if (!data || !data.email || !data.otp || !data.newPassword) {
        return res.status(400).send({ data: { success: false, message: "Missing required parameters" } });
    }

    const email = data.email.trim().toLowerCase();
    const otp = data.otp;
    const newPassword = data.newPassword;

    try {
        // 1. Verify OTP
        const otpDoc = await admin.firestore().collection("otps").doc(email).get();
        if (!otpDoc.exists) {
            return res.status(400).send({ data: { success: false, message: "No OTP found for this email" } });
        }

        const otpData = otpDoc.data();
        if (otpData.otp !== otp) {
            return res.status(400).send({ data: { success: false, message: "Invalid OTP" } });
        }

        if (otpData.expiresAt.toDate() < new Date()) {
            return res.status(400).send({ data: { success: false, message: "OTP has expired" } });
        }

        // 2. Find User in Firebase Auth
        const userRecord = await admin.auth().getUserByEmail(email);
        const uid = userRecord.uid;

        // 3. Update Password in Firebase Auth
        await admin.auth().updateUser(uid, {
            password: newPassword
        });

        // 4. Update Password in legacy 'admin' collection (Backward Compatibility)
        // Find tenantId for this admin
        const legacySnapshot = await admin.firestore().collectionGroup("admin").where("email", "==", email).get();
        if (!legacySnapshot.empty) {
            const updatePromises = legacySnapshot.docs.map(doc => doc.ref.update({ password: newPassword }));
            await Promise.all(updatePromises);
        }

        // 5. Cleanup OTP
        await admin.firestore().collection("otps").doc(email).delete();

        console.log(`[PASSWORD RESET] Successfully updated for ${email}`);
        res.send({ data: { success: true, message: "Password reset successfully" } });

    } catch (error) {
        console.error(`[RESET ERROR] Failed for ${email}:`, error);
        res.status(500).send({ data: { success: false, message: error.message } });
    }
});

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * 6. Subscription Expiry Reminder (Daily Schedule)
 * ─────────────────────────────────────────────────────────────────────────────
 * Checks for active subscriptions expiring in 3 days and sends a reminder.
 */
exports.checkSubscriptionExpiryReminders = onSchedule("0 9 * * *", async (event) => {
    console.log("[SCHEDULER] Running daily subscription reminders check at 09:00 AM IST...");

    const now = new Date();
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(now.getDate() + 3);

    // For "3 days remaining" we look at a window around exactly 3 days to avoid missing it
    const threeDaysStart = new Date(threeDaysFromNow);
    threeDaysStart.setHours(0, 0, 0, 0);
    const threeDaysEnd = new Date(threeDaysFromNow);
    threeDaysEnd.setHours(23, 59, 59, 999);

    try {
        const subscriptionsSnapshot = await admin.firestore()
            .collectionGroup("subscriptions")
            .where("status", "==", "active")
            .get();

        if (subscriptionsSnapshot.empty) {
            console.log("[SCHEDULER] No active subscriptions found.");
            return;
        }

        console.log(`[SCHEDULER] Analyzing ${subscriptionsSnapshot.size} active subscriptions...`);

        const reminderPromises = subscriptionsSnapshot.docs.map(async (doc) => {
            const subData = doc.data();
            const uid = doc.id;
            const recipientEmail = subData.corporateEmail;
            const planName = subData.planName || "Subscription";

            // Normalize expiry date (check both expiresAt Timestamp and nextBillingAt String)
            let expiryDate = null;
            if (subData.expiresAt && subData.expiresAt.toDate) {
                expiryDate = subData.expiresAt.toDate();
            } else if (subData.nextBillingAt) {
                expiryDate = new Date(subData.nextBillingAt);
            }

            if (!expiryDate || isNaN(expiryDate.getTime())) {
                console.warn(`[WARN] Invalid expiry date for sub ${doc.ref.path}`);
                return;
            }

            // Extract IDs from path
            const pathSegments = doc.ref.path.split('/');
            const tenantId = pathSegments[0];
            const appId = pathSegments[1];

            // ─── LOGIC 1: 3-Day Expiry Warning ───
            const diffDays = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

            if (diffDays === 3 && !subData.reminder3DaysSentAt) {
                console.log(`[SCHEDULER] Sending 3-day reminder for ${uid} in ${tenantId}`);

                const formattedExpiry = expiryDate.toLocaleDateString("en-IN", { day: "2-digit", month: "long", year: "numeric" });
                const title = "Subscription Expiring Soon";
                const body = `Your ${planName} subscription will expire in 3 days (${formattedExpiry}). Please renew to avoid service loss.`;

                // 1. Email
                if (recipientEmail) {
                    await admin.firestore().collection("mail").add({
                        to: recipientEmail,
                        message: {
                            subject: 'Urgent: 3 Days Remaining for Your Subscription',
                            html: `<p>Your <strong>${planName}</strong> expires on <strong>${formattedExpiry}</strong>.</p><p>Please renew your plan soon.</p>`,
                        },
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        type: "expiry_3day_warning"
                    });
                }

                // 2. Push & In-App
                await sendNotification(tenantId, appId, "admin", uid, { notification: { title, body }, data: { type: "expiry_3day" } });
                await admin.firestore().collection(tenantId).doc(appId).collection("notifications").add({
                    customerId: uid,
                    title,
                    body,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    seen: false,
                    type: "subscription_expiry"
                });

                await doc.ref.update({ reminder3DaysSentAt: admin.firestore.FieldValue.serverTimestamp() });
            }

            // ─── LOGIC 2: Monthly Status for 6-Month/Yearly ───
            if (subData.isSixMonths || subData.isYearly) {
                const startedDate = subData.startedAt ? new Date(subData.startedAt) : null;
                if (startedDate) {
                    const monthsActive = (now.getFullYear() - startedDate.getFullYear()) * 12 + (now.getMonth() - startedDate.getMonth());

                    // If it's a new month and we haven't sent a reminder this month
                    const lastSent = subData.lastMonthlyReminderSentAt ? subData.lastMonthlyReminderSentAt.toDate() : null;
                    const isNewMonth = !lastSent || (lastSent.getMonth() !== now.getMonth() || lastSent.getFullYear() !== now.getFullYear());

                    if (monthsActive > 0 && isNewMonth) {
                        console.log(`[SCHEDULER] Sending monthly status for ${uid} in ${tenantId}`);

                        const title = "Monthly Subscription Status";
                        const body = `Your ${planName} is active and running smoothly. Thank you for being with us!`;

                        // 1. Email
                        if (recipientEmail) {
                            await admin.firestore().collection("mail").add({
                                to: recipientEmail,
                                message: {
                                    subject: 'Your Monthly Subscription Status',
                                    html: `<p>Hello, your <strong>${planName}</strong> is currently active.</p><p>Next renewal date: ${expiryDate.toLocaleDateString("en-IN")}</p>`,
                                },
                                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                type: "monthly_status"
                            });
                        }

                        // 2. Push & In-App
                        await sendNotification(tenantId, appId, "admin", uid, { notification: { title, body }, data: { type: "monthly_status" } });
                        await admin.firestore().collection(tenantId).doc(appId).collection("notifications").add({
                            customerId: uid,
                            title,
                            body,
                            timestamp: admin.firestore.FieldValue.serverTimestamp(),
                            seen: false,
                            type: "monthly_status"
                        });

                        await doc.ref.update({ lastMonthlyReminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
                    }
                }
            }
        });

        await Promise.all(reminderPromises);
        console.log("[SCHEDULER] ✅ All subscription checks completed.");
    } catch (error) {
        console.error("[SCHEDULER ERROR] checkSubscriptionExpiryReminders failed:", error);
    }
});


// ─────────────────────────────────────────────────────────────────────────────
// 6. Temporary HTTP Trigger for Testing Subscription Expiry (Manual)
// ─────────────────────────────────────────────────────────────────────────────
exports.testExpiryReminder = onRequest(async (req, res) => {
    console.log("[TEST] Manually triggering subscription reminders check...");

    const now = new Date();
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(now.getDate() + 3);

    try {
        const subscriptionsSnapshot = await admin.firestore()
            .collectionGroup("subscriptions")
            .where("status", "==", "active")
            .get();

        if (subscriptionsSnapshot.empty) {
            return res.send("No active subscriptions found to test.");
        }

        let results = [];
        for (const doc of subscriptionsSnapshot.docs) {
            const subData = doc.data();
            const uid = doc.id;
            const recipientEmail = subData.corporateEmail;
            const planName = subData.planName || "Subscription";

            let expiryDate = null;
            if (subData.expiresAt && subData.expiresAt.toDate) {
                expiryDate = subData.expiresAt.toDate();
            } else if (subData.nextBillingAt) {
                expiryDate = new Date(subData.nextBillingAt);
            }

            if (!expiryDate || isNaN(expiryDate.getTime())) continue;

            const pathSegments = doc.ref.path.split('/');
            const tenantId = pathSegments[0];
            const appId = pathSegments[1];

            const diffDays = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

            if (diffDays === 3) {
                results.push(`3-DAY TRIGGER: ${uid} in ${tenantId}`);
                // In test mode, we don't check for sentAt flags to allow repeated tests
                await admin.firestore().collection("mail").add({
                    to: recipientEmail || "support@rookstechnologies.com",
                    message: { subject: '[TEST] 3-Day Warning', html: `<p>Expiring on ${expiryDate.toLocaleDateString()}</p>` },
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                });
            }

            if (subData.isSixMonths || subData.isYearly) {
                results.push(`MONTHLY CHECK: ${uid} in ${tenantId}`);
            }
        }

        res.send(`Test results: ${results.length ? results.join(", ") : "Matched no specific conditions but analyzed " + subscriptionsSnapshot.size + " docs."}`);
    } catch (error) {
        console.error("[TEST ERROR]", error);
        res.status(500).send("Error: " + error.message);
    }
});
