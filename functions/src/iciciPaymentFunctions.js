/**
 * ICICI Payment Webhook & Status Functions
 * Production Version: 12.0.0
 */

"use strict";

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const iciciService = require("./icici_service");

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * Helper to map ICICI responses to system status (SUCCESS, FAILED, PENDING).
 */
function mapICICIStatus(data) {
    if (!data) return "PENDING";

    const txnStatus = String(data.txnStatus || data.TXN_STATUS || "").trim().toUpperCase();
    const txnResponseCode = String(data.txnResponseCode || data.TXN_RESPONSE_CODE || "").trim();
    const responseCode = String(data.RESPONSE_CODE || data.responseCode || data.status || data.RESPONSECode || data.respCode || data.returnCode || data.respHeader?.returnCode || "").trim().toUpperCase();

    console.log(`[STATUS-MAP] Mapping status: txnStatus="${txnStatus}", txnResponseCode="${txnResponseCode}", responseCode="${responseCode}"`);

    if (
        txnStatus === "SUC" ||
        txnResponseCode === "0000" ||
        responseCode === "0000" ||
        responseCode === "0" ||
        responseCode === "00" ||
        responseCode === "SUCCESS" ||
        responseCode === "200"
    ) {
        return "SUCCESS";
    }

    if (
        txnStatus === "FAIL" ||
        txnStatus === "FAILED" ||
        responseCode === "1" ||
        responseCode === "1111" ||
        responseCode === "111" ||
        responseCode === "99" ||
        responseCode === "FAILED" ||
        responseCode === "CANCELLED"
    ) {
        return "FAILED";
    }

    return "PENDING";
}

/**
 * Webhook: paymentCallback
 * Securely processes bank notifications (POST webhook) and browser redirects (GET).
 *
 * ICICI sends:
 *  1. POST webhook to this URL with full transaction data.
 *  2. GET redirect when user's browser is redirected back after payment.
 * Both are handled here. The GET path simply acknowledges with an HTML page.
 */
exports.paymentCallback = onRequest(
    {
        region: "us-central1",
        vpcConnector: "icici-connector",
        vpcConnectorEgressSettings: "ALL_TRAFFIC",
        cors: true,
        timeoutSeconds: 60,
        memory: "256MiB",
        invoker: "public"
    },
    async (req, res) => {
        const TAG = "[CALLBACK]";

        // ── Handle GET (Browser redirect from ICICI after payment) ────────────
        // The user's browser lands here. Just show a friendly page — the real
        // status is handled by the POST webhook and Firestore stream in the app.
        if (req.method === "GET") {
            const txnId = req.query.ORDER_ID || req.query.merchantRefNo || req.query.merchantTxnNo || "";
            const status = req.query.status || req.query.RESPONSE_CODE || "";
            console.log(`${TAG} [GET] Browser redirect for TXN: ${txnId} | status: ${status}`);

            // Try to update Firestore based on the GET params for faster app-side detection
            if (txnId) {
                try {
                    const isSuccess = (status === "0" || status === "00" || status.toUpperCase() === "SUCCESS");
                    if (isSuccess) {
                        const paymentRef = db.collection("payments").doc(txnId);
                        const doc = await paymentRef.get();
                        if (doc.exists && doc.data().status !== "SUCCESS") {
                            await paymentRef.update({
                                status: "SUCCESS",
                                iciciResponse: { browserRedirect: req.query },
                                updatedAt: admin.firestore.FieldValue.serverTimestamp()
                            });
                            console.log(`${TAG} [GET] Updated ${txnId} to SUCCESS via browser redirect.`);
                        }
                    }
                } catch (e) {
                    console.warn(`${TAG} [GET] Firestore update error: ${e.message}`);
                }
            }

            // Return an HTML page that closes itself (deep-link back to app not needed
            // since app uses WebView which intercepts this URL).
            return res.status(200).send(`<!DOCTYPE html>
<html><head><title>Payment Processing</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font-family:Arial,sans-serif;display:flex;justify-content:center;align-items:center;
min-height:100vh;margin:0;background:#f5f5f5;}
.box{text-align:center;padding:40px;background:#fff;border-radius:12px;
box-shadow:0 4px 20px rgba(0,0,0,0.1);max-width:400px;}
h2{color:#1A237E;} p{color:#555;}
</style></head><body>
<div class="box">
<h2>&#10003; Payment Processed</h2>
<p>Your payment has been processed. Please return to the app to see the result.</p>
<p style="font-size:12px;color:#999;margin-top:20px;">You may close this window.</p>
</div>
</body></html>`);
        }

        const data = req.body;
        const query = req.query;
        const headers = req.headers;

        // Log complete callback request details as requested
        const txnId = data.ORDER_ID || data.merchantRefNo || data.merchantTxnNo || query.ORDER_ID || query.merchantRefNo || query.merchantTxnNo;

        console.log(`${TAG} [FULL LOG] Received for TXN: ${txnId}`);
        console.log(`${TAG} Headers:`, JSON.stringify(headers));
        console.log(`${TAG} Query Params:`, JSON.stringify(query));
        console.log(`${TAG} Request Body:`, JSON.stringify(data));

        if (!txnId) {
            console.error(`${TAG} Missing transaction ID in callback.`);
            return res.status(400).send("Missing ID");
        }

        try {
            // 1. Fetch transaction from Firestore
            const paymentRef = db.collection("payments").doc(txnId);

            await db.runTransaction(async (transaction) => {
                const doc = await transaction.get(paymentRef);
                if (!doc.exists) {
                    console.error(`${TAG} Transaction ${txnId} not found in Firestore.`);
                    throw new Error(`Transaction ${txnId} not found`);
                }

                const paymentData = doc.data();
                console.log(`${TAG} Existing Payment Data:`, JSON.stringify(paymentData));

                // 2. Idempotency Check
                if (paymentData.status === "SUCCESS") {
                    console.log(`${TAG} Already processed SUCCESS for ${txnId}`);
                    return;
                }

                // 3. Security Verification (Verify amount and MID)
                const bankAmount = parseFloat(data.TXN_AMOUNT || data.amount || query.TXN_AMOUNT || query.amount);
                if (!isNaN(bankAmount) && Math.abs(bankAmount - paymentData.amount) > 0.01) {
                    console.error(`${TAG} Amount mismatch! DB: ${paymentData.amount}, Bank: ${bankAmount}`);
                    transaction.update(paymentRef, {
                        status: "FAILED",
                        error: "Amount mismatch",
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    return;
                }

                // 4. Force Status Verification with Bank API (Secure Practice)
                let finalStatus = "FAILED";
                try {
                    console.log(`${TAG} Verifying status with ICICI Status API...`);
                    const verifyResult = await iciciService.statusCheck(txnId);
                    console.log(`${TAG} Status API Result:`, JSON.stringify(verifyResult));

                    if (!verifyResult.success) throw new Error("Could not verify status with bank API");

                    const statusData = verifyResult.data;
                    finalStatus = mapICICIStatus(statusData);
                } catch (e) {
                    console.error(`${TAG} Status API check failed: ${e.message}. Trusting callback data.`);
                    // Fallback to callback data (POST body or GET query)
                    const mappedDataStatus = mapICICIStatus(data);
                    if (mappedDataStatus !== "PENDING") {
                        finalStatus = mappedDataStatus;
                    } else {
                        finalStatus = mapICICIStatus(query);
                    }
                }

                console.log(`${TAG} Final calculated status for ${txnId}: ${finalStatus}`);

                // 5. Update Database
                const updateData = {
                    status: finalStatus,
                    iciciResponse: {
                        callback: data,
                        query: query,
                        finalStatus: finalStatus
                    },
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                };

                transaction.update(paymentRef, updateData);

                // 6. Mirror to Tenant Sub-collection for processPaymentSuccess trigger
                if (finalStatus === "SUCCESS" && paymentData.tenantId && paymentData.appId) {
                    const tenantRef = db.doc(`${paymentData.tenantId}/${paymentData.appId}/payment_transactions/${txnId}`);
                    const tenantData = {
                        ...paymentData,
                        ...updateData,
                        uid: paymentData.uid || paymentData.userId,
                        merchantTxnNo: paymentData.merchantTxnNo || txnId,
                        paymentMethod: paymentData.paymentMethod || paymentData.paymentMode,
                        planName: paymentData.planName || "Subscription",
                        isYearly: paymentData.isYearly || false,
                        isSixMonths: paymentData.isSixMonths || false,
                        amount: paymentData.amount,
                    };
                    transaction.set(tenantRef, tenantData, { merge: true });
                }
            });

            return res.status(200).send("OK");
        } catch (error) {
            console.error(`${TAG} Error:`, error.message);
            return res.status(200).send("Handled");
        }

    }
);

/**
 * API: verifyPayment
 * Client-side polling endpoint with whitelisted static IP egress
 */
exports.verifyPayment = onRequest(
    {
        region: "us-central1",
        vpcConnector: "icici-connector",
        vpcConnectorEgressSettings: "ALL_TRAFFIC",
        cors: true,
        timeoutSeconds: 60,
        memory: "256MiB",
        invoker: "public"
    },
    async (req, res) => {
        const { txnId } = req.body;
        if (!txnId) return res.status(400).json({ success: false, error: "Missing txnId" });

        try {
            console.log(`[VERIFY] Manual check for ${txnId}`);
            const verifyResult = await iciciService.statusCheck(txnId);
            console.log(`[VERIFY] Status API Result for ${txnId}:`, JSON.stringify(verifyResult));

            if (!verifyResult.success) {
                return res.status(200).json({ success: false, error: verifyResult.error });
            }

            const data = verifyResult.data;
            const status = mapICICIStatus(data);

            // Update DB if status changed
            if (status !== "PENDING") {
                const paymentRef = db.collection("payments").doc(txnId);
                const paymentDoc = await paymentRef.get();

                if (paymentDoc.exists) {
                    const paymentData = paymentDoc.data();
                    const updateData = {
                        status: status,
                        iciciResponse: { manualVerify: data },
                        updatedAt: admin.firestore.FieldValue.serverTimestamp()
                    };

                    await paymentRef.update(updateData);

                    // Mirror to Tenant Sub-collection if SUCCESS
                    if (status === "SUCCESS" && paymentData.tenantId && paymentData.appId) {
                        const tenantRef = db.doc(`${paymentData.tenantId}/${paymentData.appId}/payment_transactions/${txnId}`);
                        await tenantRef.set({
                            ...paymentData,
                            ...updateData,
                            uid: paymentData.uid || paymentData.userId,
                            merchantTxnNo: paymentData.merchantTxnNo || txnId,
                            paymentMethod: paymentData.paymentMethod || paymentData.paymentMode,
                        }, { merge: true });
                        console.log(`[VERIFY] Mirrored SUCCESS for ${txnId} to tenant collection.`);
                    }
                }
            }

            return res.status(200).json({ success: true, status, txnId });
        } catch (error) {
            return res.status(500).json({ success: false, error: error.message });
        }
    }
);

/**
 * API: processRefund
 * Initiates a reversal for a successful transaction
 */
exports.processRefund = onRequest(
    { cors: true, invoker: "public" },
    async (req, res) => {
        const { orderId, refundAmount } = req.body;
        if (!orderId || !refundAmount) {
            return res.status(400).json({ success: false, error: "Missing required fields" });
        }

        try {
            const result = await iciciService.processRefund(orderId, refundAmount);
            if (result.success) {
                await db.collection("payments").doc(orderId).update({
                    status: "REFUNDED",
                    refundDetails: result.data,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                return res.status(200).json({ success: true, message: "Refund processed" });
            }
            return res.status(400).json({ success: false, error: "Refund rejected by bank", raw: result.data });
        } catch (error) {
            return res.status(500).json({ success: false, error: error.message });
        }
    }
);

/**
 * API: adminProcessRefund
 * Secure HTTPS Callable for Admins to initiate refunds
 */
exports.adminProcessRefund = onCall(
    {
        region: "us-central1",
        vpcConnector: "icici-connector",
        vpcConnectorEgressSettings: "ALL_TRAFFIC",
        cors: true,
        timeoutSeconds: 60,
        memory: "256MiB"
    },
    async (request) => {
        // 1. Authenticate user
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "User must be logged in to process refunds.");
        }

        const uid = request.auth.uid;
        const { orderId, refundAmount, refundReason, adminName } = request.data;

        if (!orderId || !refundAmount || !refundReason) {
            throw new HttpsError("invalid-argument", "Missing required fields: orderId, refundAmount, or refundReason.");
        }

        try {
            // 2. Authorize Admin
            const userDoc = await db.collection("users").doc(uid).get();
            let finalAdminName = adminName || "Admin";
            
            if (userDoc.exists) {
                const userData = userDoc.data();
                if (userData.name) finalAdminName = userData.name;
            }

            // 3. Fetch Transaction
            const paymentRef = db.collection("payments").doc(orderId);
            
            const result = await db.runTransaction(async (transaction) => {
                const paymentDoc = await transaction.get(paymentRef);
                
                if (!paymentDoc.exists) {
                    throw new HttpsError("not-found", "Transaction not found.");
                }

                const paymentData = paymentDoc.data();
                
                if (paymentData.status !== "SUCCESS" && paymentData.status !== "PARTIAL_REFUND") {
                    throw new HttpsError("failed-precondition", "Only SUCCESS or PARTIAL_REFUND transactions can be refunded.");
                }

                const amountPaid = parseFloat(paymentData.amount || 0);
                const amountRequested = parseFloat(refundAmount);
                const existingRefund = parseFloat(paymentData.refundedAmount || 0);

                if (amountRequested <= 0) {
                     throw new HttpsError("invalid-argument", "Refund amount must be greater than 0.");
                }

                if ((existingRefund + amountRequested) > amountPaid) {
                     throw new HttpsError("out-of-range", "Total refund amount exceeds original payment amount.");
                }

                // 4. Call ICICI Bank API
                const bankResult = await iciciService.processRefund(orderId, amountRequested);
                
                if (!bankResult.success) {
                    throw new HttpsError("internal", "Refund rejected by bank: " + (bankResult.error || "Unknown error"), bankResult.data);
                }

                const newRefundedAmount = existingRefund + amountRequested;
                const newStatus = (newRefundedAmount >= amountPaid) ? "REFUNDED" : "PARTIAL_REFUND";

                // 5. Update Payments Collection
                const updateData = {
                    status: newStatus,
                    refundedAmount: newRefundedAmount,
                    lastRefundDate: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                };
                
                transaction.update(paymentRef, updateData);

                // 6. Create Audit Logs
                const refundId = db.collection("refunds").doc().id;
                const refundRecord = {
                    refundId: refundId,
                    orderId: orderId,
                    amount: amountRequested,
                    reason: refundReason,
                    adminUid: uid,
                    adminName: finalAdminName,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    status: "SUCCESS",
                    bankResponse: bankResult.data || {}
                };

                transaction.set(db.collection("refunds").doc(refundId), refundRecord);
                transaction.set(db.collection("refund_logs").doc(refundId), refundRecord);

                return {
                    success: true,
                    status: newStatus,
                    refundedAmount: newRefundedAmount
                };
            });

            return result;

        } catch (error) {
            console.error("[ADMIN_REFUND_ERROR]", error);
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError("internal", error.message || "An error occurred while processing the refund.");
        }
    }
);
