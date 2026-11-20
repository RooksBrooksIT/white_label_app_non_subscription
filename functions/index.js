const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
require("dotenv").config();

if (!process.env.GCLOUD_PROJECT && process.env.GCP_PROJECT_ID) {
    process.env.GCLOUD_PROJECT = process.env.GCP_PROJECT_ID;
}

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
 * Safely converts an integer or string color into a 6-digit hex code with '#'
 */
function toHexColor(colorVal, defaultHex = "#1A237E") {
    if (!colorVal) return defaultHex;
    if (typeof colorVal === "string") {
        const clean = colorVal.trim();
        if (clean.startsWith("#")) return clean;
        return "#" + clean;
    }
    if (typeof colorVal === "number") {
        const rgb = (colorVal & 0x00FFFFFF).toString(16).padStart(6, "0");
        return "#" + rgb;
    }
    return defaultHex;
}

/**
 * Dynamically resolves tenant branding (appName, logoUrl, primaryColor, etc.)
 * Priority:
 *  1. {tenantId}/{appId}/branding/config
 *  2. {tenantId}/data/branding/config
 *  3. {tenantId}/{tenantId}/branding/config
 *  4. global_user_directory/data/branding/config
 *  5. Fallback defaults (appName: 'ServNex', primaryColor: '#1A237E')
 */
async function getTenantBranding(tenantId, appId, uid) {
    const defaultBranding = {
        appName: "ServNex",
        logoUrl: "",
        primaryColor: "#1A237E",
        secondaryColor: "#0284C7",
        tagline: "Service Management Platform",
        companyName: "Rooks & Brooks Technologies Pvt. Ltd.",
        supportEmail: process.env.SMTP_USER || "support@rookstechnologies.com",
    };

    try {
        let resolvedTenant = tenantId;
        let resolvedApp = appId || "data";

        if (!resolvedTenant && uid) {
            try {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();
                if (userDoc.exists && userDoc.data().tenantId) {
                    resolvedTenant = userDoc.data().tenantId;
                } else {
                    const snap = await admin.firestore().collectionGroup("users")
                        .where(admin.firestore.FieldPath.documentId(), "==", uid)
                        .limit(1)
                        .get();
                    if (!snap.empty) {
                        resolvedTenant = snap.docs[0].ref.path.split("/")[0];
                    }
                }
            } catch (err) {
                console.warn("[BRANDING] Could not resolve tenant from uid:", err.message);
            }
        }

        const candidates = [];
        if (resolvedTenant) {
            if (resolvedApp) candidates.push(`${resolvedTenant}/${resolvedApp}/branding/config`);
            if (resolvedApp !== "data") candidates.push(`${resolvedTenant}/data/branding/config`);
            candidates.push(`${resolvedTenant}/${resolvedTenant}/branding/config`);
        }
        candidates.push("global_user_directory/data/branding/config");

        for (const docPath of candidates) {
            const snap = await admin.firestore().doc(docPath).get();
            if (snap.exists) {
                const data = snap.data();
                if (data) {
                    return {
                        appName: data.appName || data.app_name || defaultBranding.appName,
                        logoUrl: data.logoUrl || data.logo_url || "",
                        primaryColor: toHexColor(data.primaryColor, defaultBranding.primaryColor),
                        secondaryColor: toHexColor(data.secondaryColor, defaultBranding.secondaryColor),
                        tagline: data.tagline || defaultBranding.tagline,
                        companyName: defaultBranding.companyName,
                        supportEmail: defaultBranding.supportEmail,
                    };
                }
            }
        }
    } catch (e) {
        console.warn("[BRANDING] Error fetching tenant branding, falling back:", e.message);
    }

    return defaultBranding;
}

/**
 * Universal responsive HTML email template builder with dynamic branding
 */
function buildBrandedEmailHtml({
    branding,
    title,
    subtitle,
    recipientName,
    bodyHtml,
    detailsTableHtml,
    actionButtonText,
    actionButtonUrl,
    actionBadgeText,
    attachmentNote,
    additionalFooterNote
}) {
    const appName = branding?.appName || "ServNex";
    const logoUrl = branding?.logoUrl || "";
    const primaryColor = branding?.primaryColor || "#1A237E";
    const tagline = branding?.tagline || "Service Management Platform";
    const companyName = branding?.companyName || "Rooks & Brooks Technologies Pvt. Ltd.";
    const supportEmail = branding?.supportEmail || process.env.SMTP_USER || "support@rookstechnologies.com";
    const currentYear = new Date().getFullYear();

    let logoHtml = "";
    if (logoUrl && (logoUrl.startsWith("http://") || logoUrl.startsWith("https://"))) {
        logoHtml = `<img src="${logoUrl}" alt="${appName}" height="48" style="max-height:48px; max-width:200px; height:auto; object-fit:contain; display:inline-block; margin-bottom:12px; border:0;" />`;
    } else {
        const initial = (appName || "S").trim().charAt(0).toUpperCase();
        logoHtml = `
            <table cellpadding="0" cellspacing="0" border="0" style="margin:0 auto 12px auto;">
                <tr>
                    <td align="center" style="width:48px; height:48px; background-color:${primaryColor}; border-radius:10px; color:#ffffff; font-size:24px; font-weight:800; line-height:48px; text-align:center;">
                        ${initial}
                    </td>
                </tr>
            </table>
        `;
    }

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <title>${title || appName}</title>
</head>
<body style="margin:0; padding:0; background-color:#F4F6F9; font-family:'Segoe UI', Arial, Helvetica, sans-serif; -webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale; color:#334155;">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F4F6F9; padding:32px 16px;">
        <tr>
            <td align="center">
                <!-- Main Card Container -->
                <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 4px 20px rgba(0,0,0,0.06); border:1px solid #E2E8F0;">
                    
                    <!-- Top Accent Bar -->
                    <tr>
                        <td style="height:4px; background-color:${primaryColor};"></td>
                    </tr>

                    <!-- Application Branding Header -->
                    <tr>
                        <td style="padding:32px 36px 24px; text-align:center; background-color:#FAFCFE; border-bottom:1px solid #EEF2F6;">
                            ${logoHtml}
                            <div style="font-size:22px; font-weight:800; color:#0F172A; letter-spacing:0.8px; text-transform:uppercase; margin:0; line-height:1.2;">
                                ${appName}
                            </div>
                            <div style="font-size:11px; font-weight:600; color:#64748B; letter-spacing:1.2px; text-transform:uppercase; margin-top:4px;">
                                ${tagline}
                            </div>
                            ${title ? `
                            <div style="margin-top:18px; padding-top:14px; border-top:1px dashed #E2E8F0;">
                                <h1 style="font-size:20px; font-weight:700; color:${primaryColor}; margin:0; line-height:1.3;">
                                    ${title}
                                </h1>
                                ${subtitle ? `<p style="font-size:13px; color:#64748B; margin:4px 0 0 0;">${subtitle}</p>` : ''}
                            </div>
                            ` : ''}
                        </td>
                    </tr>

                    <!-- Body Content -->
                    <tr>
                        <td style="padding:28px 36px;">
                            ${recipientName ? `
                            <p style="font-size:15px; color:#1E293B; margin:0 0 16px 0; font-weight:600;">
                                Hello, ${recipientName}!
                            </p>
                            ` : ''}

                            ${bodyHtml || ''}

                            ${detailsTableHtml ? `
                            <div style="margin:20px 0;">
                                ${detailsTableHtml}
                            </div>
                            ` : ''}

                            ${attachmentNote ? `
                            <div style="background-color:#F8FAFC; border:1px solid #E2E8F0; border-radius:8px; padding:12px 16px; margin:20px 0;">
                                <p style="font-size:13px; color:#475569; margin:0; line-height:1.5;">
                                    ${attachmentNote}
                                </p>
                            </div>
                            ` : ''}

                            ${actionButtonText && actionButtonUrl ? `
                            <div style="text-align:center; margin:28px 0 10px 0;">
                                <a href="${actionButtonUrl}" style="background-color:${primaryColor}; color:#ffffff; font-size:14px; font-weight:700; padding:13px 32px; border-radius:6px; text-decoration:none; display:inline-block; box-shadow:0 2px 8px rgba(0,0,0,0.12);">
                                    ${actionButtonText}
                                </a>
                            </div>
                            ` : ''}

                            ${actionBadgeText ? `
                            <div style="text-align:center; margin:26px 0 10px 0;">
                                <span style="display:inline-block; background-color:${primaryColor}; color:#ffffff; font-size:13px; font-weight:700; padding:10px 28px; border-radius:6px;">
                                    ${actionBadgeText}
                                </span>
                            </div>
                            ` : ''}

                            ${additionalFooterNote ? `
                            <p style="font-size:13px; color:#64748B; margin:24px 0 0 0; line-height:1.5;">
                                ${additionalFooterNote}
                            </p>
                            ` : ''}
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="padding:24px 36px; background-color:#F8FAFC; border-top:1px solid #EEF2F6; text-align:center;">
                            <p style="font-size:13px; font-weight:700; color:#334155; margin:0 0 6px 0;">
                                Powered by ${appName}
                            </p>
                            <p style="font-size:12px; color:#64748B; margin:0 0 6px 0;">
                                ${companyName}
                            </p>
                            <p style="font-size:11px; color:#94A3B8; margin:0 0 12px 0;">
                                Support: <a href="mailto:${supportEmail}" style="color:${primaryColor}; text-decoration:none;">${supportEmail}</a> &nbsp;|&nbsp; +91 7598707071
                            </p>
                            <p style="font-size:11px; color:#94A3B8; margin:0; line-height:1.4;">
                                This is an automated email notification. Please do not reply directly to this message.<br>
                                &copy; ${currentYear} ${appName} &nbsp;|&nbsp; ${companyName}. All rights reserved.
                            </p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;
}

/**
 * Resolves Admin token documents across candidate tenant and app scopes.
 */
async function getAdminTokenDocs(tenantId, appId) {
    const candidates = [
        { tenant: tenantId, app: appId },
        { tenant: tenantId, app: "data" },
        { tenant: "global_user_directory", app: "data" },
        { tenant: "global_user_directory", app: appId }
    ];
    let adminDocs = [];
    for (const c of candidates) {
        if (!c.tenant || !c.app) continue;
        if (adminDocs.length > 0) break;
        try {
            const snap = await admin.firestore()
                .collection(c.tenant)
                .doc(c.app)
                .collection("notifications_tokens")
                .doc("admin")
                .collection("tokens")
                .get();
            if (!snap.empty) {
                adminDocs = snap.docs;
                console.log(`[DEBUG] Found ${adminDocs.length} admin token docs in ${c.tenant}/${c.app}`);
            }
        } catch (err) {
            console.warn(`[WARN] Admin token lookup failed in ${c.tenant}/${c.app}:`, err.message);
        }
    }
    return adminDocs;
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
        let tokens = [];
        let tokenDocRef = null;

        const appIdsToTry = Array.from(new Set([appId, "data"])).filter(Boolean);
        const tenantsToTry = Array.from(new Set([tenantId, "global_user_directory"])).filter(Boolean);

        for (const currentTenant of tenantsToTry) {
            if (tokens.length > 0) break;

            for (const currentAppId of appIdsToTry) {
                if (tokens.length > 0) break;

                const path = `${currentTenant}/${currentAppId}/notifications_tokens/${role}/tokens/${userId}`;
                console.log(`[DEBUG] Token lookup for ${role}: ${path}`);

                const tokenDoc = await admin.firestore()
                    .collection(currentTenant)
                    .doc(currentAppId)
                    .collection("notifications_tokens")
                    .doc(role)
                    .collection("tokens")
                    .doc(userId)
                    .get();

                if (tokenDoc.exists) {
                    tokenDocRef = tokenDoc.ref;
                    const data = tokenDoc.data();
                    if (data) {
                        if (Array.isArray(data.tokens) && data.tokens.length > 0) {
                            tokens.push(...data.tokens);
                        }
                        if (data.token) {
                            tokens.push(data.token);
                        }
                    }
                }

                // Query by identifiers across standard fields
                const identifiers = [
                    userId,
                    payload.data?.customerId,
                    payload.data?.customerPhone,
                    payload.data?.mobileNumber,
                    payload.data?.phone,
                    payload.data?.engineerName,
                    payload.data?.username,
                    payload.data?.userName,
                    payload.data?.email
                ].filter(Boolean);

                const fieldsToQuery = [
                    "userId", "customerId", "customerid", "email",
                    "mobileNumber", "phone", "customerPhone",
                    "username", "userName", "engineerName", "name", "displayName"
                ];

                for (const idToSearch of identifiers) {
                    if (tokens.length > 0) break;

                    for (const field of fieldsToQuery) {
                        if (tokens.length > 0) break;

                        const querySnap = await admin.firestore()
                            .collection(currentTenant)
                            .doc(currentAppId)
                            .collection("notifications_tokens")
                            .doc(role)
                            .collection("tokens")
                            .where(field, "==", idToSearch)
                            .limit(5)
                            .get();

                        for (const doc of querySnap.docs) {
                            tokenDocRef = doc.ref;
                            const d = doc.data();
                            if (Array.isArray(d.tokens)) tokens.push(...d.tokens);
                            if (d.token) tokens.push(d.token);
                        }
                    }
                }

                // Fallback: scan active tokens if still empty
                if (tokens.length === 0) {
                    const allSnap = await admin.firestore()
                        .collection(currentTenant)
                        .doc(currentAppId)
                        .collection("notifications_tokens")
                        .doc(role)
                        .collection("tokens")
                        .limit(50)
                        .get();

                    const uLower = String(userId).toLowerCase().trim();
                    for (const doc of allSnap.docs) {
                        const d = doc.data() || {};
                        const docIdLower = doc.id.toLowerCase().trim();
                        const dUid = String(d.userId || d.uid || "").toLowerCase().trim();
                        const dCustId = String(d.customerId || d.customerid || "").toLowerCase().trim();
                        const dEmail = String(d.email || "").toLowerCase().trim();
                        const dPhone = String(d.mobileNumber || d.phone || d.customerPhone || "").trim();
                        const dName = String(d.username || d.userName || d.engineerName || d.name || d.displayName || "").toLowerCase().trim();

                        const matchPhone = dPhone && (dPhone === userId || (userId.length >= 7 && dPhone.endsWith(userId)) || (dPhone.length >= 7 && userId.endsWith(dPhone)));
                        const matchName = dName && (dName === uLower || dName.includes(uLower) || uLower.includes(dName));

                        if (docIdLower === uLower || dUid === uLower || dCustId === uLower || (dEmail && dEmail === uLower) || matchPhone || matchName) {
                            tokenDocRef = doc.ref;
                            if (Array.isArray(d.tokens)) tokens.push(...d.tokens);
                            if (d.token) tokens.push(d.token);
                        }
                    }
                }
            }
        }

        // Deduplicate tokens
        tokens = Array.from(new Set(tokens)).filter(Boolean);

        if (tokens.length === 0) {
            console.warn(`[WARN] No FCM tokens found for ${userId} (${role}) in ${tenantId}/${appId}`);
            return;
        }

        console.log(`[DEBUG] Found ${tokens.length} token(s) for ${userId} (${role})`);

        const title = payload.notification?.title || payload.title || "ServNex Alert";
        const body = payload.notification?.body || payload.body || "";
        const ticketId = String(payload.data?.ticketId || payload.data?.bookingId || payload.bookingId || "");
        const notificationType = String(payload.data?.notificationType || payload.data?.type || payload.type || "general");
        const screen = String(payload.data?.screen || (role === "engineer" ? "engineer_dashboard" : role === "customer" ? "amc_main" : "admin_tickets"));

        const fcmData = {
            ticketId: ticketId,
            bookingId: ticketId,
            tenantId: String(tenantId),
            notificationType: notificationType,
            type: notificationType,
            screen: screen,
            role: String(role),
            title: title,
            body: body,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        };

        if (payload.data) {
            for (const [k, v] of Object.entries(payload.data)) {
                if (v !== undefined && v !== null) {
                    fcmData[k] = typeof v === "object" ? JSON.stringify(v) : String(v);
                }
            }
        }

        const channelId = (payload.data && (payload.data.type === "subscription_expiry" || payload.data.type === "plan_expired" || payload.data.type === "invoice"))
            ? "subscription_channel"
            : "servnex_channel";

        const sendPromises = tokens.map(async (regToken) => {
            const message = {
                token: regToken,
                notification: {
                    title: title,
                    body: body,
                },
                data: fcmData,
                android: {
                    priority: "high",
                    notification: {
                        channelId: channelId,
                        icon: "ic_stat_notification",
                        priority: "max",
                        visibility: "public",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            contentAvailable: true,
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            };

            try {
                const response = await admin.messaging().send(message);
                console.log(`[FCM SUCCESS] Notification sent to ${userId} (${role}). Message ID: ${response}`);
                return response;
            } catch (fcmError) {
                console.error(`[FCM ERROR] Failed sending to token ${regToken.substring(0, 10)}... for ${userId}:`, fcmError.message, `(code: ${fcmError.code})`);
                if (fcmError.code === "messaging/registration-token-not-registered" ||
                    fcmError.code === "messaging/invalid-registration-token") {
                    console.log(`[FCM CLEANUP] Removing dead/expired token for ${userId}`);
                    if (tokenDocRef) {
                        await tokenDocRef.update({
                            tokens: admin.firestore.FieldValue.arrayRemove(regToken)
                        }).catch(() => {});
                    }
                }
                return null;
            }
        });

        await Promise.all(sendPromises);
    } catch (error) {
        console.error(`[SYSTEM ERROR] sendNotification failed for ${userId}:`, error);
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


// 3. Notify Admin when a new ticket is raised
const handleTicketCreation = functions
    .region("us-central1")
    .firestore.document("{tenantId}/{appId}/Admin_details/{bookingId}")
    .onCreate(async (snap, context) => {
        const ticketData = snap.data();
        const { tenantId, appId, bookingId } = context.params;
    console.log(`[DEBUG] New ticket raised in ${tenantId}/${appId}: ${bookingId}`);

    try {
        const adminDocs = await getAdminTokenDocs(tenantId, appId);

        if (adminDocs.length === 0) {
            console.log(`[DEBUG] No admin token documents found to notify in ${tenantId}/${appId}`);
            return;
        }

        const payload = {
            notification: {
                title: "New Ticket Raised",
                body: `A new ticket (${bookingId}) has been raised by ${ticketData.customerName || "a customer"}`,
            },
            data: {
                type: "new_ticket",
                notificationType: "new_ticket",
                bookingId: bookingId || "",
                ticketId: bookingId || "",
                tenantId: String(tenantId),
                role: "admin",
                screen: "admin_tickets"
            },
        };

        const promises = adminDocs.map((doc) => {
            return sendNotification(tenantId, appId, "admin", doc.id, payload);
        });

        await Promise.all(promises);
        console.log(`[SUCCESS] Notified ${adminDocs.length} admin accounts for #${bookingId}`);

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

// 4. Unified Processor for Ticket Status Changes and Assignments
async function processTicketStatusUpdate(tenantId, appId, bookingId, newData, oldData, change) {
    if (!newData || !oldData) return;

    const oldStatusRaw = (oldData.status || oldData.adminStatus || oldData.engineerStatus || oldData.customerStatus || "").trim();
    const newStatusRaw = (newData.status || newData.adminStatus || newData.engineerStatus || newData.customerStatus || "").trim();
    const oldStatus = oldStatusRaw.toLowerCase();
    const newStatus = newStatusRaw.toLowerCase();

    // ── 1. Engineer Assignment Notification ──────────────────────────────
    const oldEng = (oldData.assignedEmployee || oldData.assignedEngineer || "").trim();
    const newEng = (newData.assignedEmployee || newData.assignedEngineer || "").trim();
    const isNewAssignment = newEng && newEng !== oldEng && newEng !== "Not Assigned" && newEng.toLowerCase() !== "null";

    if (isNewAssignment) {
        console.log(`[ASSIGNMENT] Assignment detected in ${tenantId}/${appId} for #${bookingId}. Engineer: ${newEng}`);
        const assignEventId = `assign_${bookingId}_${newEng.toLowerCase().replace(/[^a-z0-9]/g, "_")}`;
        const assignNotifRef = admin.firestore()
            .collection(tenantId)
            .doc(appId)
            .collection("notifications")
            .doc(assignEventId);

        const existingAssign = await assignNotifRef.get();
        if (!existingAssign.exists) {
            // Notify Engineer
            const engineerPayload = {
                notification: {
                    title: "New Assignment",
                    body: `You have been assigned a new task: ${bookingId}`,
                },
                data: {
                    type: "new_assignment",
                    notificationType: "new_assignment",
                    bookingId: String(bookingId),
                    ticketId: String(bookingId),
                    tenantId: String(tenantId),
                    role: "engineer",
                    screen: "engineer_dashboard"
                },
            };
            await sendNotification(tenantId, appId, "engineer", newEng, engineerPayload);

            // Notify Helper if present and distinct
            const helperEng = (newData.Helper1 || newData.helperEngineer || newData.helperName || "").trim();
            if (helperEng && helperEng !== "Not Assigned" && helperEng.toLowerCase() !== "null" && helperEng !== newEng) {
                const helperPayload = {
                    notification: {
                        title: "New Helper Assignment",
                        body: `You have been assigned as helper for ticket: ${bookingId}`,
                    },
                    data: {
                        type: "new_assignment",
                        notificationType: "new_assignment",
                        bookingId: String(bookingId),
                        ticketId: String(bookingId),
                        tenantId: String(tenantId),
                        role: "engineer",
                        screen: "engineer_dashboard",
                        isHelper: "true"
                    },
                };
                await sendNotification(tenantId, appId, "engineer", helperEng, helperPayload);
            }

            // Notify Customer
            const custId = (newData.id || newData.Id || newData.customerId || newData.customerid || newData.userId || newData.mobileNumber || newData.customerPhone || "").toString().trim();
            if (custId) {
                const customerPayload = {
                    notification: {
                        title: "Ticket Assigned",
                        body: `Your ticket (${bookingId}) has been assigned to ${newEng}`,
                    },
                    data: {
                        type: "ticket_assigned",
                        notificationType: "ticket_assigned",
                        bookingId: String(bookingId),
                        ticketId: String(bookingId),
                        tenantId: String(tenantId),
                        engineerName: String(newEng),
                        customerId: String(custId),
                        customerPhone: String(newData.mobileNumber || newData.customerPhone || ""),
                        customerName: String(newData.customerName || ""),
                        role: "customer",
                        screen: "amc_main"
                    },
                };
                await sendNotification(tenantId, appId, "customer", custId, customerPayload);

                await assignNotifRef.set({
                    audience: "customer",
                    customerId: String(custId),
                    customerPhone: String(newData.mobileNumber || newData.customerPhone || ""),
                    customerName: String(newData.customerName || ""),
                    bookingId: String(bookingId),
                    ticketId: String(bookingId),
                    title: "Ticket Assigned",
                    body: `Your ticket (${bookingId}) has been assigned to ${newEng}`,
                    type: "ticket_assigned",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    seen: false,
                    fcmProcessed: true,
                    fcmProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
                    additionalData: customerPayload.data
                }).catch(() => {});
            }
        }
    }

    // ── 2. Genuine Status Change Check ──────────────────────────────────
    if (!newStatus || oldStatus === newStatus) {
        // Status did not change (e.g. notes only, amount only, photo uploads, unchanged status saves)
        return;
    }

    // Cancellation handling
    const isCancelled = newStatus === "cancelled" || newStatus === "canceled";
    const wasCancelled = oldStatus === "cancelled" || oldStatus === "canceled";
    if (isCancelled && !wasCancelled) {
        console.log(`[DEBUG] Cancellation detected for ${bookingId}`);
        await processTicketCancellation(tenantId, appId, bookingId, newData, change);
        return;
    } else if (wasCancelled && !isCancelled) {
        console.log(`[SECURITY] Prevented attempt to modify or reopen cancelled ticket ${bookingId}`);
        await change.after.ref.update({
            status: "Cancelled",
            adminStatus: "Cancelled",
            engineerStatus: "Cancelled",
            fcmLastUpdateSentMillis: Date.now()
        }).catch(() => {});
        return;
    }

    // Identify Customer
    const customerId = (newData.id || newData.Id || newData.customerId || newData.customerid || newData.userId || newData.customerPhone || newData.mobileNumber || "").toString().trim();
    if (!customerId) {
        console.warn(`[WARN] Skipping status notification for #${bookingId}: No customerId found.`);
        return;
    }

    // ── 3. Idempotency Check ────────────────────────────────────────────
    const normalizedKey = newStatus.replace(/[^a-z0-9]/g, "_");
    const statusEventDocId = `status_${bookingId}_${normalizedKey}`;
    const statusNotifRef = admin.firestore()
        .collection(tenantId)
        .doc(appId)
        .collection("notifications")
        .doc(statusEventDocId);

    const existingDoc = await statusNotifRef.get();
    if (existingDoc.exists) {
        console.log(`[IDEMPOTENT] Status notification ${statusEventDocId} already exists. Skipping duplicate.`);
        return;
    }

    if (newData.lastNotifiedStatus && newData.lastNotifiedStatus.toLowerCase() === newStatus) {
        console.log(`[IDEMPOTENT] Ticket #${bookingId} already notified for status ${newStatus}. Skipping.`);
        return;
    }

    // ── 4. Dynamic Notification Content (Section 7 Specifications) ──────
    let title = "Service Ticket Update";
    let body = `Your service ticket ${bookingId} status is now: ${newStatusRaw}.`;
    let type = "status_update";

    if (newStatus === "in progress" || newStatus.includes("progress")) {
        title = "Service Work Started";
        body = `Your service ticket ${bookingId} is now In Progress.`;
        type = "service_in_progress";
    } else if (newStatus === "completed" || newStatus === "complete") {
        title = "Service Completed";
        body = `Your service ticket ${bookingId} has been completed successfully. Please share your rating and feedback.`;
        type = "ticket_completed_feedback";
    } else if (newStatus === "delivered") {
        title = "Service Delivered";
        body = `Your service ticket ${bookingId} has been marked as Delivered.`;
        type = "service_delivered";
    } else if (newStatus === "ready for delivery" || newStatus.includes("ready")) {
        title = "Service Ready";
        body = `Your service ticket ${bookingId} is ready for delivery.`;
        type = "ready_for_delivery";
    } else if (newStatus === "open") {
        title = "Service Ticket Open";
        body = `Your service ticket ${bookingId} is now Open.`;
        type = "status_update";
    } else if (newStatus === "assigned") {
        const engName = newData.assignedEmployee || newData.assignedEngineer || "an engineer";
        title = "Ticket Assigned";
        body = `Your ticket (${bookingId}) has been assigned to ${engName}.`;
        type = "ticket_assigned";
    }

    const payload = {
        notification: { title, body },
        data: {
            ticketId: String(bookingId),
            bookingId: String(bookingId),
            tenantId: String(tenantId),
            customerId: String(customerId),
            customerPhone: String(newData.mobileNumber || newData.customerPhone || ""),
            customerName: String(newData.customerName || ""),
            status: String(newStatusRaw),
            type: String(type),
            notificationType: String(type),
            role: "customer",
            targetRole: "customer",
            screen: type === "ticket_completed_feedback" ? "customer_feedback" : "amc_main",
            deviceBrand: String(newData.deviceBrand || ""),
            deviceType: String(newData.deviceType || ""),
            engineerName: String(newData.assignedEmployee || newData.assignedEngineer || "")
        }
    };

    // ── 5. Create Persistent Notification in History ────────────────────
    await statusNotifRef.set({
        audience: "customer",
        customerId: String(customerId),
        customerName: String(newData.customerName || ""),
        bookingId: String(bookingId),
        ticketId: String(bookingId),
        title: title,
        body: body,
        type: type,
        status: String(newStatusRaw),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        seen: false,
        fcmProcessed: true,
        fcmProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
        additionalData: payload.data
    }).catch(err => console.error("[NOTIF] Error creating notification history:", err));

    // ── 6. Send FCM Push Notification ──────────────────────────────────
    try {
        await sendNotification(tenantId, appId, "customer", customerId, payload);
        console.log(`[SUCCESS] FCM status notification sent to customer ${customerId} for #${bookingId} -> ${newStatusRaw}`);
    } catch (e) {
        console.error(`[ERROR] Failed to send FCM push for status update to ${customerId}:`, e);
    }

    // ── 7. Mandatory Feedback & Ticket Flags ────────────────────────────
    const isCompleted = newStatus === "completed" || newStatus === "complete";
    const updatePayload = {
        lastNotifiedStatus: newStatusRaw,
        fcmLastUpdateSentMillis: Date.now()
    };
    if (isCompleted) {
        updatePayload.completionFeedbackNotificationSent = true;
        updatePayload.isFeedbackMandatory = true;
        updatePayload.feedbackSubmitted = false;
    }

    await change.after.ref.update(updatePayload).catch(() => {});
}

// 4. Notify Customer when ticket status is updated (Admin_details compatibility)
const handleTicketStatusUpdate = functions
    .region("us-central1")
    .firestore.document("{tenantId}/{appId}/Admin_details/{bookingId}")
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const { tenantId, appId, bookingId } = context.params;
        await processTicketStatusUpdate(tenantId, appId, bookingId, newData, oldData, change);
    });

/**
 * 5. Trigger FCM Push Notification whenever an in-app notification document is created in Firestore
 * Handles all notification types dispatched by the app: Ticket Assignment, Visit Scheduling,
 * Helper Assignment, Ticket Cancellation, Reassignment, and System Alerts.
 */
const handleNotificationDocument = functions
    .region("us-central1")
    .firestore.document("{tenantId}/{appId}/notifications/{notificationId}")
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const { tenantId, appId, notificationId } = context.params;

        if (!data || data.fcmProcessed === true) {
            return;
        }

        const audience = (data.audience || "admin").toLowerCase().trim();
        const title = data.title || "ServNex Alert";
        const body = data.body || "";
        const bookingId = data.bookingId || data.ticketId || "";
        const type = data.type || "general";

        console.log(`[NOTIF TRIGGER] Processing notification ${notificationId} in ${tenantId}/${appId} for audience: ${audience} (type: ${type})`);

        const payload = {
            notification: { title, body },
            data: {
                ticketId: String(bookingId),
                bookingId: String(bookingId),
                tenantId: String(tenantId),
                notificationType: String(type),
                type: String(type),
                role: String(audience),
                screen: String(data.screen || (audience === "engineer" ? "engineer_dashboard" : audience === "customer" ? "amc_main" : "admin_tickets")),
                ...(data.additionalData || {})
            }
        };

        try {
            if (audience === "engineer") {
                // Primary engineer
                const primaryName = (data.engineerName || data.assignedEmployee || data.userId || "").trim();
                if (primaryName) {
                    console.log(`[NOTIF TRIGGER] Sending FCM push to primary engineer: ${primaryName}`);
                    await sendNotification(tenantId, appId, "engineer", primaryName, payload);
                }

                // Helper engineer if assigned
                const helperName = (data.additionalData?.helperEngineer || data.helperName || data.Helper1 || "").trim();
                if (helperName && helperName !== primaryName) {
                    console.log(`[NOTIF TRIGGER] Sending FCM push to helper engineer: ${helperName}`);
                    await sendNotification(tenantId, appId, "engineer", helperName, payload);
                }
            } else if (audience === "customer") {
                const customerId = (data.customerId || data.id || data.userId || data.customerPhone || data.mobileNumber || "").trim();
                if (customerId) {
                    console.log(`[NOTIF TRIGGER] Sending FCM push to customer: ${customerId}`);
                    if (data.customerPhone || data.mobileNumber) {
                        payload.data.customerPhone = String(data.customerPhone || data.mobileNumber);
                    }
                    await sendNotification(tenantId, appId, "customer", customerId, payload);
                }
            } else if (audience === "admin") {
                console.log(`[NOTIF TRIGGER] Sending FCM push to admins in ${tenantId}/${appId}`);
                const adminDocs = await getAdminTokenDocs(tenantId, appId);

                if (adminDocs.length > 0) {
                    const promises = adminDocs.map(doc => {
                        return sendNotification(tenantId, appId, "admin", doc.id, payload);
                    });
                    await Promise.all(promises);
                }
            }

            await snap.ref.update({
                fcmProcessed: true,
                fcmProcessedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } catch (err) {
            console.error(`[NOTIF TRIGGER ERROR] Failed processing notification ${notificationId}:`, err);
        }
    });

/**
 * 6. Notify Admin when a customer raises a ticket directly in Raised_tickets
 */
const handleRaisedTicketCreation = functions
    .region("us-central1")
    .firestore.document("{tenantId}/{appId}/Raised_tickets/{bookingId}")
    .onCreate(async (snap, context) => {
        const ticketData = snap.data();
        const { tenantId, appId, bookingId } = context.params;
        console.log(`[DEBUG] New raised ticket in ${tenantId}/${appId}: ${bookingId}`);

        try {
            const adminDocs = await getAdminTokenDocs(tenantId, appId);

            if (adminDocs.length === 0) {
                console.log(`[DEBUG] No admin tokens found to notify for raised ticket #${bookingId}`);
                return;
            }

            const payload = {
                notification: {
                    title: "New Ticket Raised",
                    body: `A new ticket (${bookingId}) has been raised by ${ticketData.customerName || "a customer"}`,
                },
                data: {
                    type: "new_ticket",
                    notificationType: "new_ticket",
                    bookingId: bookingId || "",
                    ticketId: bookingId || "",
                    tenantId: String(tenantId),
                    role: "admin",
                    screen: "admin_tickets"
                },
            };

            const promises = adminDocs.map((doc) => {
                return sendNotification(tenantId, appId, "admin", doc.id, payload);
            });
            await Promise.all(promises);
        } catch (e) {
            console.error("[SYSTEM ERROR] handleRaisedTicketCreation failed:", e);
        }
    });

/**
 * Helper to process ticket cancellations across Admin_ticket_entry and Raised_tickets
 */
async function processTicketCancellation(tenantId, appId, bookingId, newData, change) {
    const reason = newData.cancellationReason || newData.Reason_cancel || "Cancelled";
    const isCustomerCancellation = (newData.cancelledByRole || "").toLowerCase() === "customer";
    const now = Date.now();

    if (isCustomerCancellation) {
        console.log(`[DEBUG] Customer cancelled ticket ${bookingId}, notifying Admin`);
        const adminDocs = await getAdminTokenDocs(tenantId, appId);

        if (adminDocs.length > 0) {
            const adminPayload = {
                notification: {
                    title: "Customer Cancelled Service Ticket",
                    body: `Customer ${newData.customerName || "Customer"} has cancelled ticket #${bookingId}. Reason: ${reason}`
                },
                data: {
                    notificationType: "customer_ticket_cancelled",
                    type: "customer_ticket_cancelled",
                    bookingId: String(bookingId),
                    ticketId: String(bookingId),
                    tenantId: String(tenantId),
                    customerId: String(newData.customerId || newData.customerid || newData.id || ""),
                    customerPhone: String(newData.mobileNumber || newData.customerPhone || ""),
                    cancelledAt: String(now),
                    targetRole: "admin",
                    role: "admin",
                    screen: "admin_tickets"
                }
            };
            const promises = adminDocs.map(doc => sendNotification(tenantId, appId, "admin", doc.id, adminPayload));
            await Promise.all(promises);
        }
    } else {
        // Cancelled by Admin: notify customer
        const customerId = (newData.id || newData.Id || newData.customerId || newData.customerid || newData.userId || newData.mobileNumber || newData.customerPhone || "").toString().trim();
        if (customerId) {
            await sendNotification(tenantId, appId, "customer", customerId, {
                notification: {
                    title: "Service Ticket Cancelled",
                    body: `Your service ticket ${bookingId} has been cancelled by the administration. Reason: ${reason}`
                },
                data: {
                    type: "ticket_cancelled",
                    notificationType: "ticket_cancelled",
                    bookingId: String(bookingId),
                    ticketId: String(bookingId),
                    tenantId: String(tenantId),
                    customerId: String(customerId),
                    customerPhone: String(newData.mobileNumber || newData.customerPhone || ""),
                    role: "customer",
                    cancellationReason: String(reason)
                }
            });
        }
    }

    // In both cases, notify primary engineer and helper engineer if assigned
    const primaryEngineer = (newData.assignedEmployee || newData.assignedEngineer || "").trim();
    if (primaryEngineer && primaryEngineer !== "Not Assigned" && primaryEngineer.toLowerCase() !== "null") {
        const engTitle = isCustomerCancellation ? "Ticket Cancelled by Customer" : "Ticket Cancelled";
        const engBody = isCustomerCancellation
            ? `Ticket #${bookingId} for customer ${newData.customerName || "Customer"} has been cancelled. Reason: ${reason}. This ticket is now read-only.`
            : `Ticket ${bookingId} has been cancelled. This ticket is now read-only.`;

        await sendNotification(tenantId, appId, "engineer", primaryEngineer, {
            notification: {
                title: engTitle,
                body: engBody
            },
            data: {
                type: "ticket_cancelled",
                bookingId: String(bookingId),
                ticketId: String(bookingId),
                role: "engineer",
                cancellationReason: String(reason),
                cancelledByRole: String(newData.cancelledByRole || (isCustomerCancellation ? "customer" : "admin"))
            }
        });
    }

    const helperEngineer = (newData.Helper1 || newData.helperEngineer || newData.helperName || "").trim();
    if (helperEngineer && helperEngineer !== "Not Assigned" && helperEngineer !== primaryEngineer) {
        const helperTitle = isCustomerCancellation ? "Ticket Cancelled by Customer" : "Ticket Cancelled";
        const helperBody = isCustomerCancellation
            ? `Helper assignment for ticket #${bookingId} has been cancelled by customer.`
            : `Helper assignment for ticket ${bookingId} has been cancelled.`;

        await sendNotification(tenantId, appId, "engineer", helperEngineer, {
            notification: {
                title: helperTitle,
                body: helperBody
            },
            data: {
                type: "ticket_cancelled",
                bookingId: String(bookingId),
                ticketId: String(bookingId),
                role: "engineer",
                cancellationReason: String(reason),
                cancelledByRole: String(newData.cancelledByRole || (isCustomerCancellation ? "customer" : "admin"))
            }
        });
    }

    await change.after.ref.update({ fcmLastUpdateSentMillis: now }).catch(() => {});
}

async function processTicketCompletionFeedback(tenantId, appId, bookingId, newData, change) {
    if (newData.completionFeedbackNotificationSent === true) {
        return;
    }

    const customerId = (newData.id || newData.customerId || newData.customerid || "").toString().trim();
    const customerName = (newData.customerName || "").toString().trim();

    if (!customerId) {
        console.log(`[DEBUG] Cannot send completion feedback notification for ${bookingId}: missing customerId`);
        return;
    }

    console.log(`[DEBUG] Sending completion feedback push notification for ${bookingId} to customer ${customerId}`);

    const payload = {
        notification: {
            title: "Service Completed – Share Your Feedback",
            body: `Your service ticket ${bookingId} has been completed successfully. Please share your rating and feedback about our service.`,
        },
        data: {
            ticketId: String(bookingId),
            bookingId: String(bookingId),
            tenantId: String(tenantId),
            customerId: String(customerId),
            customerName: String(customerName),
            notificationType: "ticket_completed_feedback",
            type: "ticket_completed_feedback",
            role: "customer",
            targetRole: "customer",
        },
    };

    try {
        await sendNotification(tenantId, appId, "customer", customerId, payload);
    } catch (e) {
        console.error(`[ERROR] Failed to send push notification for completion feedback: ${e}`);
    }

    try {
        await createPersistentNotification(tenantId, appId, {
            audience: "customer",
            customerId: customerId,
            customerName: customerName,
            bookingId: bookingId,
            title: "Service Completed – Share Your Feedback",
            body: `Your service ticket ${bookingId} has been completed successfully. Please share your rating and feedback about our service.`,
            type: "ticket_completed_feedback",
        });
    } catch (e) {
        console.error(`[ERROR] Failed to create persistent completion notification: ${e}`);
    }

    try {
        await change.after.ref.update({
            completionFeedbackNotificationSent: true,
        });
    } catch (e) {
        console.error(`[ERROR] Failed to update completionFeedbackNotificationSent on ticket: ${e}`);
    }
}

/**
 * 7. Monitor Admin_ticket_entry updates (status changes, assignments, cancellations, completion)
 */
const handleAdminTicketEntryUpdate = functions
    .region("us-central1")
    .firestore.document("{tenantId}/{appId}/Admin_ticket_entry/{bookingId}")
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const { tenantId, appId, bookingId } = context.params;

        await processTicketStatusUpdate(tenantId, appId, bookingId, newData, oldData, change);
    });

/**
 * 8. Monitor Raised_tickets updates for status changes, assignments and cancellations
 */
const handleRaisedTicketUpdate = functions
    .region("us-central1")
    .firestore.document("{tenantId}/{appId}/Raised_tickets/{bookingId}")
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const { tenantId, appId, bookingId } = context.params;

        await processTicketStatusUpdate(tenantId, appId, bookingId, newData, oldData, change);
    });

// 4. Send Email via Nodemailer when a document is created or updated in the "mail" collection
const processMailDocument = functions
    .region("us-central1")
    .firestore.document("mail/{docId}")
    .onWrite(async (change, context) => {
        const data = change.after.exists ? change.after.data() : null;
        
        // Skip if document was deleted or missing required fields
        if (!data || !data.to) return null;

        // Only process if status is pending. 
        // RETRY status is handled by the scheduledEmailRetry function which resets it to PENDING.
        const status = data.status || { state: "PENDING" };
        if (status.state !== "PENDING") return null;

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

        const fromAppName = data.appName || data.fromName || process.env.COMPANY_NAME || "ServNex";
        const mailOptions = {
            from: `"${fromAppName}" <${process.env.SMTP_USER || "support@rookstechnologies.com"}>`,
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

            return change.after.ref.update({
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

            return change.after.ref.update({
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
const scheduledEmailRetry = functions
    .region("us-central1")
    .pubsub.schedule("*/30 * * * *")
    .timeZone("UTC")
    .onRun(async (context) => {
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
const processPaymentSuccess = functions
    .region("us-central1")
    .runWith({ memory: "256MB", timeoutSeconds: 60 })
    .firestore.document("{tenantId}/{appId}/payment_transactions/{txnId}")
    .onWrite(async (change, context) => {
        const newData = change.after.exists ? change.after.data() : null;
        const oldData = change.before.exists ? change.before.data() : null;
        const { tenantId, appId, txnId } = context.params;

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
            const subscriptionYears = parseInt(newData.subscriptionYears || newData.billingYears || 1, 10) || 1;
            const billingCycle = newData.isYearly
                ? (subscriptionYears > 1 ? `${subscriptionYears} Years` : "Yearly")
                : (newData.isSixMonths ? "6 Months" : "Monthly");
            const paymentMethod = newData.paymentMethod || "Online";
            const transactionId = newData.merchantTxnNo || newData.paymentId || txnId;

            // ── 4. Calculate Subscription Dates for PDF ───────────────────
            const startD = new Date();
            const endD = new Date();
            if (newData.isYearly) {
                endD.setFullYear(endD.getFullYear() + subscriptionYears);
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

            // ── 5. Fetch Tenant Branding & Build Responsive HTML Email ────
            const branding = await getTenantBranding(tenantId, "data", uid);

            const detailsTableHtml = `
              <table width="100%" cellpadding="10" cellspacing="0" border="0" style="background-color:#F8FAFC; border-radius:8px; border:1px solid #E2E8F0; font-size:13px; color:#334155;">
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Invoice No</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:700; color:#0F172A;">${invoiceNo}</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Date</strong></td>
                  <td align="right" style="padding:10px 14px;">${formattedDate} at ${formattedTime}</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Plan</strong></td>
                  <td align="right" style="padding:10px 14px; font-weight:600; color:${branding.primaryColor};">${planName} (${billingCycle})</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Transaction ID</strong></td>
                  <td align="right" style="padding:10px 14px; font-size:11px; font-family:monospace; color:#64748B;">${transactionId}</td>
                </tr>
                <tr style="border-bottom:1px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Payment Method</strong></td>
                  <td align="right" style="padding:10px 14px;">${paymentMethod}</td>
                </tr>
                <tr style="border-bottom:0.5px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>Subtotal (ex-GST)</strong></td>
                  <td align="right" style="padding:10px 14px;">₹${baseAmount}</td>
                </tr>
                <tr style="border-bottom:0.5px solid #E2E8F0;">
                  <td style="padding:10px 14px; color:#64748B;"><strong>GST (18%)</strong></td>
                  <td align="right" style="padding:10px 14px;">₹${gstAmount}</td>
                </tr>
                <tr style="background-color:${branding.primaryColor}; border-radius:0 0 8px 8px;">
                  <td style="padding:12px 14px; color:#ffffff; font-size:14px; font-weight:700; border-radius:0 0 0 6px;">Total Paid</td>
                  <td align="right" style="padding:12px 14px; color:#ffffff; font-size:16px; font-weight:800; border-radius:0 0 6px 0;">₹${totalAmount}</td>
                </tr>
              </table>
            `;

            const bodyHtml = `
              <p style="font-size:14px; color:#475569; margin:0 0 16px 0; line-height:1.6;">
                Your subscription payment was <strong style="color:#16A34A;">successful</strong>.
                Your official invoice has been generated and is attached to this email as a PDF.
              </p>
            `;

            const htmlEmail = buildBrandedEmailHtml({
                branding,
                title: "Payment Confirmed — Receipt & Invoice",
                subtitle: `Invoice #${invoiceNo}`,
                recipientName: userName,
                bodyHtml,
                detailsTableHtml,
                attachmentNote: "📎 A detailed <strong>PDF invoice</strong> is attached to this email for your records.",
                actionBadgeText: "✓ &nbsp; Subscription Active"
            });

            // ── 6. Write to 'mail' collection → triggers processMailDocument ──
            await admin.firestore().collection("mail").add({
                to: recipientEmail,
                appName: branding.appName,
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
            await change.after.ref.update({
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
                expiryDate.setFullYear(expiryDate.getFullYear() + subscriptionYears);
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
                subscriptionYears: subscriptionYears,
                billingYears: subscriptionYears,
                durationYears: subscriptionYears,
                annualPrice: newData.isYearly ? Math.round(totalAmount / subscriptionYears) : null,
                totalAmount: totalAmount,
                billingType: newData.isYearly ? "Yearly" : (newData.isSixMonths ? "6 Months" : "Monthly"),
                billingCycle: billingCycle,
                price: totalAmount,
                startedAt: admin.firestore.FieldValue.serverTimestamp(),
                startDate: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: admin.firestore.Timestamp.fromDate(expiryDate),
                expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
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
const logPaymentActivity = functions
    .region("us-central1")
    .firestore.document("payments/{txnId}")
    .onWrite(async (change, context) => {
        const newData = change.after.exists ? change.after.data() : null;
        const { txnId } = context.params;

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
const scheduledSubscriptionReminders = functions
    .region("us-central1")
    .pubsub.schedule("0 3 * * *")
    .timeZone("UTC")
    .onRun(async (context) => {
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

    // 2. Fetch Tenant Branding & Generate Email Content
    const branding = await getTenantBranding(tenantId, "data", uid);
    const daysLeft = type === "twoDay" ? 2 : 1;
    const subject = `Urgent: Your ${planName} expires in ${daysLeft} day${daysLeft > 1 ? "s" : ""}!`;

    const detailsTableHtml = `
      <table width="100%" cellpadding="12" cellspacing="0" border="0" style="background-color:#F8FAFC; border-left:4px solid ${branding.primaryColor}; border-radius:6px; font-size:14px; border:1px solid #E2E8F0; border-left-width:4px;">
        <tr style="border-bottom:1px solid #E2E8F0;">
          <td style="padding:10px 16px; color:#64748B; font-size:13px;">Plan Name:</td>
          <td align="right" style="padding:10px 16px; font-weight:700; color:${branding.primaryColor};">${planName}</td>
        </tr>
        <tr style="border-bottom:1px solid #E2E8F0;">
          <td style="padding:10px 16px; color:#64748B; font-size:13px;">Expiry Date:</td>
          <td align="right" style="padding:10px 16px; font-weight:700; color:#DC2626;">${formattedExpiry}</td>
        </tr>
        <tr>
          <td style="padding:10px 16px; color:#64748B; font-size:13px;">Time Remaining:</td>
          <td align="right" style="padding:10px 16px; font-weight:800; color:#DC2626;">${daysLeft} day${daysLeft > 1 ? "s" : ""}</td>
        </tr>
      </table>
    `;

    const bodyHtml = `
      <p style="font-size:14px; color:#334155; line-height:1.6; margin:0 0 14px 0;">
        This is a friendly reminder that your <strong>${planName}</strong> subscription is set to expire in <strong>${daysLeft} day${daysLeft > 1 ? "s" : ""}</strong> on <strong>${formattedExpiry}</strong>.
      </p>
      <p style="font-size:14px; color:#334155; line-height:1.6; margin:0 0 14px 0;">
        To ensure uninterrupted access to all your professional tools, data and workflows, we recommend renewing your plan today.
      </p>
    `;

    const htmlContent = buildBrandedEmailHtml({
        branding,
        title: "Subscription Expiring Soon",
        subtitle: `Urgent Reminder — ${daysLeft} day${daysLeft > 1 ? "s" : ""} remaining`,
        bodyHtml,
        detailsTableHtml,
        actionButtonText: "Renew Subscription Now",
        actionButtonUrl: "https://rookstechnologies.com/renew",
        additionalFooterNote: "If you have already renewed, please disregard this notice."
    });

    // 3. Queue Email
    await db.collection("mail").add({
        to: recipientEmail,
        appName: branding.appName,
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

// 7. Send OTP for Forgot Password
const sendOTP = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
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

        // Send Branded Email
        const branding = await getTenantBranding(data.tenantId, data.appId);
        const otpHtml = buildBrandedEmailHtml({
            branding,
            title: "Password Reset Request",
            subtitle: "One-Time Password (OTP)",
            bodyHtml: `
              <p style="font-size:14px; line-height:1.6; color:#334155; margin:0 0 16px 0;">
                You requested to reset your password for your <strong>${branding.appName}</strong> account. Use the verification code below to proceed:
              </p>
              <div style="text-align:center; margin:26px 0;">
                <div style="display:inline-block; background-color:#F8FAFC; border:2px dashed ${branding.primaryColor}; border-radius:8px; padding:12px 28px; font-size:28px; font-weight:800; letter-spacing:6px; color:${branding.primaryColor}; font-family:monospace;">
                  ${otp}
                </div>
                <p style="font-size:12px; color:#DC2626; margin:8px 0 0 0; font-weight:600;">
                  This code will expire in 10 minutes.
                </p>
              </div>
              <p style="font-size:13px; color:#64748B; line-height:1.5; margin:16px 0 0 0;">
                If you did not request a password reset, please ignore this email or contact support if you suspect unauthorized activity.
              </p>
            `
        });

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
            from: `"${branding.appName}" <${process.env.SMTP_USER || "support@rookstechnologies.com"}>`,
            to: email,
            subject: `Your Password Reset OTP — ${branding.appName}`,
            html: otpHtml
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
const verifyOTPAndResetPassword = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
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
const checkSubscriptionExpiryReminders = functions
    .region("us-central1")
    .runWith({ memory: "256MB" })
    .pubsub.schedule("0 9 * * *")
    .timeZone("Asia/Kolkata")
    .retryConfig({ retryCount: 0 })
    .onRun(async (context) => {

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

                // 1. Fetch Tenant Branding & Build Email Template
                const branding = await getTenantBranding(tenantId, appId, uid);
                const detailsTableHtml = `
                  <table width="100%" cellpadding="12" cellspacing="0" border="0" style="background-color:#F8FAFC; border-left:4px solid ${branding.primaryColor}; border-radius:6px; font-size:14px; border:1px solid #E2E8F0; border-left-width:4px;">
                    <tr style="border-bottom:1px solid #E2E8F0;">
                      <td style="padding:10px 16px; color:#64748B; font-size:13px;">Plan Name:</td>
                      <td align="right" style="padding:10px 16px; font-weight:700; color:${branding.primaryColor};">${planName}</td>
                    </tr>
                    <tr style="border-bottom:1px solid #E2E8F0;">
                      <td style="padding:10px 16px; color:#64748B; font-size:13px;">Expiry Date:</td>
                      <td align="right" style="padding:10px 16px; font-weight:700; color:#DC2626;">${formattedExpiry}</td>
                    </tr>
                    <tr>
                      <td style="padding:10px 16px; color:#64748B; font-size:13px;">Time Remaining:</td>
                      <td align="right" style="padding:10px 16px; font-weight:800; color:#DC2626;">${dayLabel}</td>
                    </tr>
                  </table>
                `;

                const bodyHtml = `
                  <p style="font-size:14px; color:#334155; line-height:1.6; margin:0 0 14px 0;">
                    This is an urgent reminder that your <strong>${planName}</strong> subscription will expire in <strong>${dayLabel}</strong> on <strong>${formattedExpiry}</strong>.
                  </p>
                  <p style="font-size:14px; color:#334155; line-height:1.6; margin:0 0 14px 0;">
                    To ensure uninterrupted access to your features and business data, please renew or upgrade your plan.
                  </p>
                `;

                const emailHtml = buildBrandedEmailHtml({
                    branding,
                    title: "Subscription Expiry Reminder",
                    subtitle: `Action Required — ${dayLabel} Remaining`,
                    bodyHtml,
                    detailsTableHtml,
                    actionButtonText: "Renew Subscription",
                    actionButtonUrl: "https://rookstechnologies.com/renew",
                    additionalFooterNote: `If you have already renewed, please ignore this email. Thank you for choosing ${branding.appName}.`
                });

                if (recipientEmail) {
                    await admin.firestore().collection("mail").add({
                        to: recipientEmail,
                        appName: branding.appName,
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

                        // 1. Fetch Tenant Branding & Build Email Template
                        const branding = await getTenantBranding(tenantId, appId, uid);
                        const detailsTableHtml = `
                          <table width="100%" cellpadding="12" cellspacing="0" border="0" style="background-color:#F8FAFC; border-left:4px solid ${branding.primaryColor}; border-radius:6px; font-size:14px; border:1px solid #E2E8F0; border-left-width:4px;">
                            <tr style="border-bottom:1px solid #E2E8F0;">
                              <td style="padding:10px 16px; color:#64748B; font-size:13px;">Plan Name:</td>
                              <td align="right" style="padding:10px 16px; font-weight:700; color:${branding.primaryColor};">${planName}</td>
                            </tr>
                            <tr style="border-bottom:1px solid #E2E8F0;">
                              <td style="padding:10px 16px; color:#64748B; font-size:13px;">Status:</td>
                              <td align="right" style="padding:10px 16px; font-weight:700; color:#16A34A;">Active &amp; Healthy</td>
                            </tr>
                            <tr>
                              <td style="padding:10px 16px; color:#64748B; font-size:13px;">Next Renewal Date:</td>
                              <td align="right" style="padding:10px 16px; font-weight:700; color:#0F172A;">${expiryDate.toLocaleDateString("en-IN", { day: "2-digit", month: "long", year: "numeric" })}</td>
                            </tr>
                          </table>
                        `;

                        const bodyHtml = `
                          <p style="font-size:14px; color:#334155; line-height:1.6; margin:0 0 14px 0;">
                            Hello, your <strong>${planName}</strong> subscription is currently active and running smoothly.
                          </p>
                          <p style="font-size:14px; color:#334155; line-height:1.6; margin:0 0 14px 0;">
                            Thank you for being a valued customer with <strong>${branding.appName}</strong>. We are committed to empowering your service operations.
                          </p>
                        `;

                        const monthlyHtml = buildBrandedEmailHtml({
                            branding,
                            title: "Monthly Subscription Status",
                            subtitle: "Account Active & Healthy",
                            bodyHtml,
                            detailsTableHtml,
                            actionButtonText: "Manage Subscription",
                            actionButtonUrl: "https://rookstechnologies.com/renew",
                        });

                        if (recipientEmail) {
                            await admin.firestore().collection("mail").add({
                                to: recipientEmail,
                                appName: branding.appName,
                                message: {
                                    subject: `Your Monthly Subscription Status — ${planName}`,
                                    html: monthlyHtml,
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


/**
 * ─────────────────────────────────────────────────────────────────────────────
 * 7. Payment Reconciliation Scheduler (Hourly)
 * ─────────────────────────────────────────────────────────────────────────────
 * Automatically recovers PENDING payments that were never completed by 
 * verifying their status with ICICI Bank after 30 minutes.
 */
const reconcileStuckPayments = functions
    .region("us-central1")
    .runWith({
        memory: "256MB",
        vpcConnector: "icici-connector",
        vpcConnectorEgressSettings: "ALL_TRAFFIC",
    })
    .pubsub.schedule("0 * * * *")
    .timeZone("Asia/Kolkata")
    .retryConfig({ retryCount: 1 })
    .onRun(async (context) => {
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

// ===== CARD, NET BANKING & UPI PAYMENT SESSION =====
// Primary payment initiation endpoint — handles CARD, NETBANKING, UPI
const { createPaymentSession } = require("./src/createPaymentSession");

// ===== EXPORTS (ALL PRODUCTION FUNCTIONS) =====

// Firestore Triggers
exports.handleTicketCreation = handleTicketCreation;
exports.handleTicketStatusUpdate = handleTicketStatusUpdate;
exports.handleNotificationDocument = handleNotificationDocument;
exports.handleRaisedTicketCreation = handleRaisedTicketCreation;
exports.handleRaisedTicketUpdate = handleRaisedTicketUpdate;
exports.handleAdminTicketEntryUpdate = handleAdminTicketEntryUpdate;
exports.processMailDocument = processMailDocument;
exports.processPaymentSuccess = processPaymentSuccess;
exports.logPaymentActivity = logPaymentActivity;

// Schedulers & Expiry Reminders
exports.scheduledEmailRetry = scheduledEmailRetry;
exports.scheduledSubscriptionReminders = scheduledSubscriptionReminders;
exports.checkSubscriptionExpiryReminders = checkSubscriptionExpiryReminders;
exports.reconcileStuckPayments = reconcileStuckPayments;

// OTP & Account
exports.sendOTP = sendOTP;
exports.verifyOTPAndResetPassword = verifyOTPAndResetPassword;

// ICICI Payment Gateway
exports.processRefund = iciciFunctions.processRefund;
exports.adminProcessRefund = iciciFunctions.adminProcessRefund;
exports.paymentCallback = iciciFunctions.paymentCallback;
exports.paymentReturn = iciciFunctions.paymentCallback;
exports.verifyPayment = iciciFunctions.verifyPayment;
exports.createPaymentSession = createPaymentSession;



