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

/**
 * Creates a persistent notification document in Firestore.
 **/
async function createPersistentNotification(tenantId, appId, payload) {
    try {
        await admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("notifications")
            .add({
                ...payload,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                seen: false
            });
        console.log(`[SUCCESS] Persistent notification created for ${payload.audience || "unknown audience"}`);
    } catch (error) {
        console.error(`[SYSTEM ERROR] createPersistentNotification failed:`, error);
    }
}

// 1. HTTP Test Function: Send notification to any user
// Usage: https://<region>-<project>.cloudfunctions.net/testNotify?tenantId=white-label-app-33300&appId=data&role=engineer&userId=JohnDoe
exports.testNotify = onRequest({ invoker: "public" }, async (req, res) => {
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

        // 2. Create persistent notification for admins
        await createPersistentNotification(tenantId, appId, {
            audience: "admin",
            title: payload.notification.title,
            body: payload.notification.body,
            type: payload.data.type,
            bookingId: payload.data.bookingId,
            customerName: ticketData.customerName || "a customer"
        });
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
            await createPersistentNotification(tenantId, appId, {
                audience: "customer",
                customerId: newData.id,
                customerName: newData.customerName || "",
                bookingId: bookingId,
                title: "Ticket Assigned",
                body: `Your ticket (${bookingId}) has been assigned to ${newData.assignedEmployee}`,
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
            await createPersistentNotification(tenantId, appId, {
                audience: "customer",
                customerId: newData.id,
                customerName: newData.customerName || "",
                bookingId: bookingId,
                title: "Ticket Update",
                body: `Your ticket (${bookingId}) status is now: ${currentStatus}`,
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

            // Also create a persistent notification for admins
            await createPersistentNotification(tenantId, appId, {
                audience: "admin",
                title: adminPayload.notification.title,
                body: adminPayload.notification.body,
                type: adminPayload.data.type,
                bookingId: adminPayload.data.bookingId,
                status: adminPayload.data.status,
                engineerName: adminPayload.data.engineerName
            });
        }
    }
});

// 4. Send Email via Nodemailer when a document is created or updated in the "mail" collection
exports.processMailDocument = onDocumentWritten("mail/{docId}", async (event) => {
    const data = event.data.after ? event.data.after.data() : null;
    
    // Skip if document was deleted or missing required fields
    if (!data || !data.to) return;

    // Only process if status is pending. 
    // RETRY status is handled by the scheduledEmailRetry function which resets it to PENDING.
    const status = data.status || { state: "PENDING" };
    if (status.state !== "PENDING") return;

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
        to: data.to,
        subject: data.message.subject,
        html: data.message.html,
        attachments: (data.message.attachments || []).map((att) => ({
            filename: att.filename,
            content: att.content,
            encoding: "base64",
            contentType: att.contentType,
        })),
    };

    try {
        console.log(`[EMAIL] Attempting to send to ${data.to} | Subject: "${data.message.subject}"`);
        await transporter.sendMail(mailOptions);
        console.log(`[EMAIL] Successfully sent to ${data.to}`);

        return event.data.after.ref.update({
            status: { 
                state: "SENT", 
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                attempts: (status.attempts || 0) + 1
            },
        });
    } catch (error) {
        const attempts = (status.attempts || 0) + 1;
        const maxAttempts = 3;
        const canRetry = attempts < maxAttempts;

        console.error(`[EMAIL ERROR] Attempt ${attempts}/${maxAttempts} failed for ${data.to}:`, error.message);

        return event.data.after.ref.update({
            status: {
                state: canRetry ? "RETRY" : "ERROR",
                error: error.message,
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
                attempts: attempts,
                nextRetryAt: canRetry ? admin.firestore.Timestamp.fromDate(new Date(Date.now() + (Math.pow(2, attempts) * 60000))) : null // Exponential backoff
            },
        });
    }
});

// 4.5. Scheduled Email Retry
//     Schedule: Every 30 minutes
//     Action: Resets documents in 'RETRY' state back to 'PENDING' if their nextRetryAt has passed.
exports.scheduledEmailRetry = onSchedule("*/30 * * * *", async (event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db.collection("mail")
        .where("status.state", "==", "RETRY")
        .get();

    const promises = [];
    snapshot.forEach(doc => {
        const data = doc.data();
        if (data.status.nextRetryAt && data.status.nextRetryAt.toDate() <= now.toDate()) {
            console.log(`[EMAIL RETRY] Resetting ${doc.id} for another attempt.`);
            promises.push(doc.ref.update({ "status.state": "PENDING" }));
        }
    });

    return Promise.all(promises);
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
                doc.text(`${baseAmount}`, col.price, y + 15, { width: 80, align: "right" });
                doc.text("18", col.gst, y + 15, { width: 50, align: "center" });
                doc.text(`${totalAmount}`, col.total, y + 15, { width: 85, align: "right" });

                // ── Summary Section ─────────────────────────────────────────
                y += 60;
                const summaryW = 220;
                const summaryH = 40;
                doc.rect(R - summaryW, y, summaryW, summaryH).fill(ACCENT_BLUE);
                doc.font("Helvetica-Bold").fontSize(11).fillColor("#FFFFFF");
                doc.text("Invoice Total", R - summaryW + 15, y + 15);
                doc.text(`${totalAmount}`, R - summaryW, y + 15, { width: summaryW - 15, align: "right" });

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
                <td align="right">₹${baseAmount}</td>
              </tr>
              <tr style="border-bottom:0.5px solid #E0E0E0;">
                <td><strong>GST (18%)</strong></td>
                <td align="right">₹${gstAmount}</td>
              </tr>
              <tr style="background:#1A237E;border-radius:4px;">
                <td style="color:#fff;font-size:15px;border-radius:4px 0 0 4px;"><strong>Total Paid</strong></td>
                <td align="right" style="color:#fff;font-size:17px;font-weight:700;border-radius:0 4px 4px 0;">
                  ₹${totalAmount}
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
            // Skip subscription update if UID is a placeholder (PENDING_...)
            // The Flutter app will handle registration and subscription update after success.
            if (uid.startsWith("PENDING_")) {
                console.log(`[LIFECYCLE] Skipping subscription update for placeholder UID: ${uid}`);
                return;
            }

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
                .doc(tenantId) // Standardized to tenantId to avoid duplication with 'data' bucket
                .collection("subscription")
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
                reminderSent: false, // Legacy field
                remindersSent: {
                    twoDay: false,
                    oneDay: false,
                },
                reminder3DaysSentAt: null,
                reminder2DaysSentAt: null,
                reminder1DaySentAt: null,
                corporateEmail: recipientEmail,
                limits: newData.limits || null,
                geoLocation: newData.geoLocation || false,
                attendance: newData.attendance || false,
                barcode: newData.barcode || false,
                reportExport: newData.reportExport || false,
            }, { merge: true });

            console.log(`[LIFECYCLE] Updated subscription for ${uid} | expires=${expiryDate.toISOString()}`);

        } catch (error) {
            console.error(`[RECEIPT ERROR] processPaymentSuccess failed for ${txnId}:`, error);
        }
    });

// ─────────────────────────────────────────────────────────────────────────────
// 5.5. Real-time Payment Activity Logging
//     Trigger: payments/{txnId} (Any write/update)
//     Action: Mirrored to {tenantId}/{appId}/payment_logs/{txnId} for auditing.
// ─────────────────────────────────────────────────────────────────────────────
exports.logPaymentActivity = onDocumentWritten("payments/{txnId}", async (event) => {
    const newData = event.data.after ? event.data.after.data() : null;
    const { txnId } = event.params;

    if (!newData || !newData.tenantId || !newData.appId) {
        console.warn(`[LOG] Skipping log for ${txnId}: Missing tenantId or appId`);
        return;
    }

    // NEW RULE: Only mirror to tenant bucket once a terminal status (SUCCESS/FAILED) is reached.
    // This prevents premature creation of tenant collections if the user cancels before paying.
    const status = newData.status || "PENDING";
    if (status === "PENDING") {
        console.log(`[LOG] Skipping mirror for ${txnId}: Status is still PENDING.`);
        return;
    }

    const { tenantId, appId } = newData;
    console.log(`[LOG] Recording activity for TXN: ${txnId} in ${tenantId}/${appId}`);

    try {
        const logData = {
            userId: newData.userId || newData.uid || "unknown",
            planName: newData.planName || "Subscription",
            transactionId: txnId,
            paymentAmount: newData.amount || 0,
            paymentStatus: newData.status || "PENDING",
            paymentMethod: newData.paymentMethod || newData.paymentMode || "Online",
            timestamp: newData.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
            errorMessage: newData.error || null,
            email: newData.email || null,
            customerName: newData.customerName || null,
            // Audit fields
            loggedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "Cloud Function Trigger"
        };

        // Write to tenant-specific logs collection
        // Using txnId as the doc ID ensures we update the existing log rather than duplicating
        await admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("payment_logs")
            .doc(txnId)
            .set(logData, { merge: true });

        console.log(`[LOG] ✅ Successfully logged activity for ${txnId}`);
    } catch (error) {
        console.error(`[LOG ERROR] Failed to log payment activity for ${txnId}:`, error.message);
    }
});

// ─────────────────────────────────────────────────────────────────────────────
// 10. Automated Subscription Expiry Reminders
//     Schedule: Daily at 09:00 AM IST (03:30 AM UTC)
//     Action: Scans all active subscriptions and sends emails 2 days and 1 day before expiry.
// ─────────────────────────────────────────────────────────────────────────────
exports.scheduledSubscriptionReminders = onSchedule("0 3 * * *", async (event) => {
    console.log("[REMINDER] Starting daily subscription expiry check...");
    const now = new Date();
    const db = admin.firestore();

    try {
        // Query all active subscriptions across all tenants
        const subscriptionsSnapshot = await db.collectionGroup("subscription")
            .where("status", "==", "active")
            .get();

        console.log(`[REMINDER] Found ${subscriptionsSnapshot.size} active subscriptions to check.`);

        const promises = [];

        for (const doc of subscriptionsSnapshot.docs) {
            const data = doc.data();
            const expiresAt = data.expiresAt ? data.expiresAt.toDate() : null;

            if (!expiresAt) continue;

            const diffTime = expiresAt.getTime() - now.getTime();
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            let reminderType = null;
            const remindersSent = data.remindersSent || { twoDay: false, oneDay: false };

            if (diffDays === 2 && !remindersSent.twoDay) {
                reminderType = "twoDay";
            } else if (diffDays === 1 && !remindersSent.oneDay) {
                reminderType = "oneDay";
            }

            if (reminderType) {
                promises.push(sendExpiryReminder(doc.ref, data, expiresAt, reminderType));
            }
        }

        await Promise.all(promises);
        console.log(`[REMINDER] Daily check completed. Processed ${promises.length} reminders.`);
    } catch (error) {
        console.error("[REMINDER ERROR] Failed to process scheduled reminders:", error);
    }
});

/**
 * Helper to send expiry reminder email and update document
 */
async function sendExpiryReminder(docRef, data, expiresAt, type) {
    const db = admin.firestore();
    const uid = docRef.id;
    const pathSegments = docRef.path.split("/");
    const tenantId = pathSegments[0];
    const planName = data.planName || "Subscription Plan";
    const formattedExpiry = expiresAt.toLocaleDateString("en-IN", { day: "2-digit", month: "long", year: "numeric" });

    // 1. Determine recipient email
    let recipientEmail = data.corporateEmail;

    if (!recipientEmail) {
        // Fallback: Check user document in tenant
        const userDoc = await db.collection(tenantId).doc("data")
            .collection("users").doc(uid).get();
        if (userDoc.exists) {
            recipientEmail = userDoc.data().email;
        }
    }

    if (!recipientEmail) {
        // Final fallback: Auth
        try {
            const authUser = await admin.auth().getUser(uid);
            recipientEmail = authUser.email;
        } catch (e) {
            console.warn(`[REMINDER] Could not find email for user ${uid} in tenant ${tenantId}`);
            return;
        }
    }

    if (!recipientEmail) return;

    console.log(`[REMINDER] Sending ${type} reminder to ${recipientEmail} for plan ${planName}`);

    // 2. Generate Email Content
    const daysLeft = type === "twoDay" ? 2 : 1;
    const subject = `Urgent: Your ${planName} expires in ${daysLeft} day${daysLeft > 1 ? "s" : ""}!`;

    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Subscription Expiry Reminder</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F4F6F9; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F4F6F9; padding: 40px 0;">
        <tr>
            <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="background-color: #1A237E; padding: 40px; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Subscription Expiring Soon</h1>
                        </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                        <td style="padding: 40px;">
                            <p style="font-size: 16px; color: #333; line-height: 1.6; margin-top: 0;">
                                Hello,
                            </p>
                            <p style="font-size: 16px; color: #333; line-height: 1.6;">
                                This is a friendly reminder that your <strong>${planName}</strong> is set to expire in <strong>${daysLeft} day${daysLeft > 1 ? "s" : ""}</strong> on <strong>${formattedExpiry}</strong>.
                            </p>
                            <p style="font-size: 16px; color: #333; line-height: 1.6;">
                                To ensure uninterrupted access to all our professional tools and features, we recommend renewing your plan today.
                            </p>

                            <!-- Plan Details Box -->
                            <div style="background-color: #F8F9FA; border-radius: 8px; padding: 20px; margin: 30px 0; border-left: 4px solid #1A237E;">
                                <table width="100%">
                                    <tr>
                                        <td style="color: #666; font-size: 14px; padding-bottom: 5px;">Plan Name:</td>
                                        <td align="right" style="color: #1A237E; font-weight: bold;">${planName}</td>
                                    </tr>
                                    <tr>
                                        <td style="color: #666; font-size: 14px;">Expiry Date:</td>
                                        <td align="right" style="color: #1A237E; font-weight: bold;">${formattedExpiry}</td>
                                    </tr>
                                </table>
                            </div>

                            <p style="font-size: 16px; color: #333; line-height: 1.6; text-align: center;">
                                Click the button below to renew your subscription:
                            </p>

                            <div style="text-align: center; margin-top: 30px;">
                                <a href="https://rookstechnologies.com/renew" style="background-color: #1A237E; color: #ffffff; padding: 15px 35px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                                    Renew Subscription Now
                                </a>
                            </div>
                        </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 30px; border-top: 1px solid #EEEEEE; text-align: center;">
                            <p style="font-size: 12px; color: #999; margin: 0;">
                                &copy; ${new Date().getFullYear()} Rooks & Brooks Technologies. All rights reserved.
                            </p>
                            <p style="font-size: 12px; color: #999; margin: 10px 0 0;">
                                Support: support@rookstechnologies.com
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
    `;

    // 3. Queue Email
    await db.collection("mail").add({
        to: recipientEmail,
        message: {
            subject: subject,
            html: htmlContent,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: "expiry_reminder",
        reminderType: type,
        uid: uid,
        tenantId: tenantId,
    });

    // 4. Update Subscription Record to prevent duplicates
    const updateData = {};
    updateData[`remindersSent.${type}`] = true;
    updateData[`reminder${type === "twoDay" ? "2Days" : "1Day"}SentAt`] = admin.firestore.FieldValue.serverTimestamp();

    await docRef.update(updateData);
    console.log(`[REMINDER] ✅ ${type} reminder queued and recorded for ${recipientEmail}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. HTTP Test Function: Manually trigger expiry checks
// ─────────────────────────────────────────────────────────────────────────────
exports.testExpiryReminders = onRequest({ invoker: "public" }, async (req, res) => {
    console.log("[HTTP TEST] Manually triggering expiry reminders...");
    const now = new Date();
    const db = admin.firestore();

    try {
        const subscriptionsSnapshot = await db.collectionGroup("subscription")
            .where("status", "==", "active")
            .get();

        const results = [];

        for (const doc of subscriptionsSnapshot.docs) {
            const data = doc.data();
            const expiresAt = data.expiresAt ? data.expiresAt.toDate() : null;

            if (!expiresAt) continue;

            const diffTime = expiresAt.getTime() - now.getTime();
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            let reminderType = null;
            const remindersSent = data.remindersSent || { twoDay: false, oneDay: false };

            if (diffDays === 2 && !remindersSent.twoDay) {
                reminderType = "twoDay";
            } else if (diffDays === 1 && !remindersSent.oneDay) {
                reminderType = "oneDay";
            }

            if (reminderType) {
                await sendExpiryReminder(doc.ref, data, expiresAt, reminderType);
                results.push({ uid: doc.id, type: reminderType, email: data.corporateEmail || "unknown" });
            }
        }

        res.send({
            success: true,
            message: `Processed ${results.length} reminders.`,
            details: results
        });
    } catch (error) {
        console.error("[HTTP TEST ERROR]", error);
        res.status(500).send({ success: false, error: error.message });
    }
});

// 7. Send OTP for Forgot Password
exports.sendOTP = onRequest({ invoker: "public" }, async (req, res) => {
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
exports.verifyOTPAndResetPassword = onRequest({ invoker: "public" }, async (req, res) => {
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
exports.checkSubscriptionExpiryReminders = onSchedule({
    schedule:   "0 9 * * *",
    timeZone:   "Asia/Kolkata",
    retryCount: 0,
    memory:     "256MiB",
}, async (event) => {

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
            .collectionGroup("subscription")
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

            // ─── LOGIC 1: Expiry Warning Reminders (3, 2, and 1 day) ───
            const diffDays = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));
            const formattedExpiry = expiryDate.toLocaleDateString("en-IN", { day: "2-digit", month: "long", year: "numeric" });

            if ((diffDays === 3 && !subData.reminder3DaysSentAt) || 
                (diffDays === 2 && !subData.reminder2DaysSentAt) || 
                (diffDays === 1 && !subData.reminder1DaySentAt)) {
                
                let dayLabel = `${diffDays} days`;
                if (diffDays === 1) dayLabel = "24 hours";
                
                console.log(`[SCHEDULER] Sending ${dayLabel} reminder for ${uid} in ${tenantId}`);

                const title = `Subscription Expiring in ${dayLabel}`;
                const body = `Your ${planName} subscription will expire in ${dayLabel} (${formattedExpiry}). Please renew to avoid service loss.`;

                // 1. Email Template
                const emailHtml = `
                    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
                        <div style="background-color: ${BRAND_BLUE}; padding: 20px; text-align: center;">
                            <h1 style="color: white; margin: 0; font-size: 24px;">Subscription Reminder</h1>
                        </div>
                        <div style="padding: 30px; color: #333; line-height: 1.6;">
                            <p>Hello,</p>
                            <p>This is a reminder that your <strong>${planName}</strong> subscription is about to expire.</p>
                            
                            <div style="background-color: ${BRAND_BLUE_LIGHT}; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid ${BRAND_BLUE};">
                                <p style="margin: 0;"><strong>Expiry Date:</strong> ${formattedExpiry}</p>
                                <p style="margin: 5px 0 0 0;"><strong>Time Remaining:</strong> ${dayLabel}</p>
                            </div>

                            <p>To ensure uninterrupted access to your features and data, please renew or upgrade your plan.</p>
                            
                            <div style="text-align: center; margin: 30px 0;">
                                <a href="https://rookstechnologies.com/renew" style="background-color: ${BRAND_BLUE}; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">Renew Subscription</a>
                            </div>

                            <p style="font-size: 14px; color: #666;">If you have already renewed, please ignore this email. Thank you for choosing ${process.env.COMPANY_NAME || "Rooks And Brooks"}.</p>
                        </div>
                        <div style="background-color: #f9f9f9; padding: 20px; text-align: center; font-size: 12px; color: #999; border-top: 1px solid #eeeeee;">
                            <p style="margin: 0;">&copy; ${new Date().getFullYear()} ${process.env.COMPANY_NAME || "Rooks And Brooks"}. All rights reserved.</p>
                        </div>
                    </div>
                `;

                if (recipientEmail) {
                    await admin.firestore().collection("mail").add({
                        to: recipientEmail,
                        message: {
                            subject: `Urgent: ${dayLabel} Remaining for Your Subscription`,
                            html: emailHtml,
                        },
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        type: `expiry_${diffDays}day_warning`
                    });
                }

                // 2. Push & In-App
                await sendNotification(tenantId, appId, "admin", uid, { 
                    notification: { title, body }, 
                    data: { type: `expiry_${diffDays}day`, expiryDate: formattedExpiry } 
                });

                await createPersistentNotification(tenantId, appId, {
                    audience: "admin",
                    customerId: uid,
                    title,
                    body,
                    type: "subscription_expiry"
                });

                // Update correct flag
                const updateField = diffDays === 3 ? "reminder3DaysSentAt" : 
                                   diffDays === 2 ? "reminder2DaysSentAt" : "reminder1DaySentAt";
                
                await doc.ref.update({ [updateField]: admin.firestore.FieldValue.serverTimestamp() });
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
                        await createPersistentNotification(tenantId, appId, {
                            audience: "admin",
                            customerId: uid,
                            title,
                            body,
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
exports.testExpiryReminder = onRequest({ invoker: "public" }, async (req, res) => {
    console.log("[TEST] Manually triggering subscription reminders check...");

    const now = new Date();
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(now.getDate() + 3);

    try {
        const subscriptionsSnapshot = await admin.firestore()
            .collectionGroup("subscription")
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

            if (diffDays === 3 || diffDays === 2 || diffDays === 1) {
                results.push(`${diffDays}-DAY TRIGGER: ${uid} in ${tenantId}`);
                // In test mode, we don't check for sentAt flags to allow repeated tests
                await admin.firestore().collection("mail").add({
                    to: recipientEmail || "support@rookstechnologies.com",
                    message: { 
                        subject: `[TEST] ${diffDays}-Day Warning`, 
                        html: `<p>Expiring on ${expiryDate.toLocaleDateString()}</p>` 
                    },
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

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * 7. Payment Reconciliation Scheduler (Hourly)
 * ─────────────────────────────────────────────────────────────────────────────
 * Automatically recovers PENDING payments that were never completed by 
 * verifying their status with ICICI Bank after 30 minutes.
 */
exports.reconcileStuckPayments = onSchedule({
    schedule:   "0 * * * *", // Every hour
    timeZone:   "Asia/Kolkata",
    retryCount: 1,
    memory:     "256MiB",
}, async (event) => {
    console.log("[RECONCILE] Running hourly payment reconciliation...");

    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const iciciService = require("./src/icici_service");

    try {
        const pendingSnap = await admin.firestore()
            .collection("payments")
            .where("status", "==", "PENDING")
            .where("createdAt", "<=", admin.firestore.Timestamp.fromDate(thirtyMinutesAgo))
            .limit(50)
            .get();

        if (pendingSnap.empty) {
            console.log("[RECONCILE] No stuck PENDING payments found.");
            return;
        }

        console.log(`[RECONCILE] Found ${pendingSnap.size} stuck payments. Starting verification...`);

        const reconcilePromises = pendingSnap.docs.map(async (doc) => {
            const txnId = doc.id;
            const data = doc.data();

            try {
                const verifyResult = await iciciService.statusCheck(txnId);
                if (!verifyResult.success) return;

                const statusData = verifyResult.data;
                const respCode = statusData?.RESPONSE_CODE || statusData?.responseCode || statusData?.respHeader?.returnCode;

                let finalStatus = "PENDING";
                if (respCode === "0" || respCode === "00" || respCode === "SUCCESS" || respCode === "200") {
                    finalStatus = "SUCCESS";
                } else if (respCode === "1" || respCode === "99" || respCode === "FAILED") {
                    finalStatus = "FAILED";
                }

                if (finalStatus !== "PENDING") {
                    console.log(`[RECONCILE] Updating ${txnId} to ${finalStatus}`);
                    await doc.ref.update({
                        status: finalStatus,
                        reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
                        iciciResponse: { reconciliation: statusData }
                    });

                    // Trigger successful payment logic if needed (Receipts, etc.)
                    // This will be handled by the 'onDocumentWritten' trigger for processPaymentSuccess
                }
            } catch (err) {
                console.error(`[RECONCILE ERROR] Failed for ${txnId}:`, err.message);
            }
        });

        await Promise.all(reconcilePromises);
        console.log("[RECONCILE] ✅ Hourly reconciliation completed.");
    } catch (error) {
        console.error("[RECONCILE FATAL]", error);
    }
});

// ===== ICICI PAYMENT GATEWAY FUNCTIONS =====
const iciciFunctions = require("./src/iciciPaymentFunctions");

// processRefund  → called by Flutter admin panel for refunds
// paymentCallback → webhook called by ICICI after payment
// verifyPayment   → called by Flutter app to poll status
exports.processRefund    = iciciFunctions.processRefund;
exports.adminProcessRefund = iciciFunctions.adminProcessRefund;
exports.paymentCallback  = iciciFunctions.paymentCallback;
exports.verifyPayment    = iciciFunctions.verifyPayment;

// ===== CARD, NET BANKING & UPI PAYMENT SESSION =====
// Primary payment initiation endpoint — handles CARD, NETBANKING, UPI
const { createPaymentSession } = require("./src/createPaymentSession");
exports.createPaymentSession = createPaymentSession;

