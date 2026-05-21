/**
 * Firebase Functions Index - Complete Implementation
 * File: functions/index.js
 * 
 * This shows how to integrate ICICI payment functions into your existing Firebase setup
 * IMPORTANT: This is a reference - merge with your existing index.js
 */

const { onDocumentUpdated, onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
require("dotenv").config();

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

// ===== EXISTING UTILITY FUNCTIONS =====

/**
 * Converts a number into words (Indian Numbering System)
 * [YOUR EXISTING CODE HERE - numberToWords, sendNotification, etc.]
 */

// ===== ICICI PAYMENT FUNCTIONS =====

/**
 * Import ICICI payment functions
 */
const {
  initiatePayment,
  checkPaymentStatus,
  processRefund,
  paymentCallback,
  testPaymentFlow
} = require('./src/iciciPaymentFunctions');

// Export ICICI payment functions
exports.initiatePayment = initiatePayment;
exports.checkPaymentStatus = checkPaymentStatus;
exports.processRefund = processRefund;
exports.paymentCallback = paymentCallback;
exports.testPaymentFlow = testPaymentFlow;

// ===== PAYMENT MONITORING & LOGGING =====

/**
 * Firestore Trigger: Monitor payment status changes
 * Automatically sends notifications when payment status changes
 */
exports.onPaymentStatusChanged = onDocumentWritten(
  "payments/{orderId}",
  async (event) => {
    try {
      const before = event.data.before.data();
      const after = event.data.after.data();

      // Only process if status actually changed
      if (before?.status === after?.status) {
        return;
      }

      console.log(`[PAYMENT] Status changed: ${before?.status} → ${after?.status} for Order: ${event.params.orderId}`);

      // Send notification to user on status change
      if (after?.userId && after?.status === 'SUCCESS') {
        await sendPaymentSuccessNotification(after?.userId, after);
      }

      if (after?.status === 'FAILED') {
        await sendPaymentFailedNotification(after?.userId, after);
      }

    } catch (error) {
      console.error("[PAYMENT] Status change handler error:", error);
    }
  }
);

/**
 * Send payment success notification
 */
async function sendPaymentSuccessNotification(userId, paymentData) {
  try {
    const message = {
      notification: {
        title: "💳 Payment Successful!",
        body: `₹${paymentData.amount} payment confirmed. Order: ${paymentData.orderId}`
      },
      data: {
        orderId: paymentData.orderId,
        amount: paymentData.amount.toString(),
        transactionId: paymentData.transactionId || "",
        type: "payment_success"
      },
      webpush: {
        fcmOptions: {
          link: "/subscription/confirmation"
        }
      }
    };

    // Get user FCM tokens and send notification
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists && userDoc.data().fcmTokens?.length > 0) {
      await admin.messaging().sendMulticast({
        tokens: userDoc.data().fcmTokens,
        ...message
      });
    }

    console.log(`[NOTIFICATION] Payment success notification sent to ${userId}`);
  } catch (error) {
    console.error("[NOTIFICATION] Error sending success notification:", error);
  }
}

/**
 * Send payment failed notification
 */
async function sendPaymentFailedNotification(userId, paymentData) {
  try {
    const message = {
      notification: {
        title: "❌ Payment Failed",
        body: `₹${paymentData.amount} payment could not be processed. Please try again.`
      },
      data: {
        orderId: paymentData.orderId,
        amount: paymentData.amount.toString(),
        error: "Payment processing failed",
        type: "payment_failed"
      }
    };

    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists && userDoc.data().fcmTokens?.length > 0) {
      await admin.messaging().sendMulticast({
        tokens: userDoc.data().fcmTokens,
        ...message
      });
    }

    console.log(`[NOTIFICATION] Payment failed notification sent to ${userId}`);
  } catch (error) {
    console.error("[NOTIFICATION] Error sending failed notification:", error);
  }
}

// ===== SCHEDULED TASKS FOR PAYMENT RECONCILIATION =====

/**
 * Scheduled Function: Check pending payments every 5 minutes
 * Queries ICICI for status of payments that haven't received callback
 */
exports.reconcilePendingPayments = onSchedule(
  {
    schedule: "every 5 minutes",
    timeoutSeconds: 300,
    memory: "512MB"
  },
  async (context) => {
    try {
      console.log("[RECONCILIATION] Starting pending payment reconciliation");

      const ICICIPaymentService = require('./src/iciciPaymentService');
      const iciciService = new ICICIPaymentService();

      // Find payments initiated but not completed (older than 10 minutes)
      const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);

      const pendingPayments = await db
        .collection('payments')
        .where('status', '==', 'INITIATED')
        .where('initiatedAt', '<', tenMinutesAgo)
        .limit(10) // Check max 10 at a time
        .get();

      console.log(`[RECONCILIATION] Found ${pendingPayments.docs.length} pending payments`);

      for (const doc of pendingPayments.docs) {
        const payment = doc.data();

        try {
          // Query ICICI for status
          const statusResult = await iciciService.processCommand({
            orderId: payment.orderId,
            command: 'STATUS_QUERY',
            customerId: payment.customerId
          });

          if (statusResult.success) {
            const iciciStatus = statusResult.data.RESPONSE_CODE;
            let finalStatus = 'PENDING';

            if (iciciStatus === '0') finalStatus = 'SUCCESS';
            else if (iciciStatus === '1') finalStatus = 'FAILED';

            // Update if status changed
            if (finalStatus !== 'PENDING') {
              await db.collection('payments').doc(payment.orderId).update({
                status: finalStatus,
                reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
                iciciReconcileResponse: statusResult.data
              });

              console.log(`[RECONCILIATION] Updated ${payment.orderId} to ${finalStatus}`);

              // Send notification
              if (finalStatus === 'SUCCESS') {
                await sendPaymentSuccessNotification(payment.userId, {
                  ...payment,
                  transactionId: statusResult.data.TXN_ID
                });
              }
            }
          }
        } catch (error) {
          console.error(`[RECONCILIATION] Error checking ${payment.orderId}:`, error);
        }
      }

      console.log("[RECONCILIATION] Completed");

    } catch (error) {
      console.error("[RECONCILIATION] Error:", error);
    }
  }
);

// ===== CLEANUP JOBS =====

/**
 * Scheduled Function: Clean up old test payments
 * Removes test payments older than 30 days
 */
exports.cleanupOldPayments = onSchedule(
  {
    schedule: "every day 02:00", // 2 AM daily
    timeoutSeconds: 300
  },
  async (context) => {
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      const testPayments = await db
        .collection('payments')
        .where('orderId', '>=', 'TEST_')
        .where('orderId', '<', 'TEST_\uf8ff')
        .where('completedAt', '<', thirtyDaysAgo)
        .get();

      console.log(`[CLEANUP] Deleting ${testPayments.docs.length} old test payments`);

      // Delete in batches
      for (const doc of testPayments.docs) {
        await doc.ref.delete();
      }

    } catch (error) {
      console.error("[CLEANUP] Error:", error);
    }
  }
);

// ===== HTTP ENDPOINT FOR TESTING =====

/**
 * Health Check Endpoint
 * Use to verify Firebase Functions are deployed
 */
exports.healthCheck = onRequest(
  {
    cors: true
  },
  async (req, res) => {
    try {
      const status = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        functions: {
          initiatePayment: '✓',
          checkPaymentStatus: '✓',
          processRefund: '✓',
          paymentCallback: '✓'
        },
        database: 'connected',
        version: '1.0'
      };

      res.status(200).json(status);
    } catch (error) {
      res.status(500).json({
        status: 'unhealthy',
        error: error.message
      });
    }
  }
);

// ===== ANALYTICS & REPORTING =====

/**
 * Get Payment Analytics
 * Returns payment statistics for dashboard
 */
exports.getPaymentAnalytics = onRequest(
  {
    cors: ['https://yourdomain.com'],
    enforceAppCheck: true
  },
  async (req, res) => {
    try {
      const idToken = req.headers.authorization?.split('Bearer ')[1];
      if (!idToken) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const decodedToken = await admin.auth().verifyIdToken(idToken);

      // Get current month
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

      // Query payments for current month
      const snapshot = await db
        .collection('payments')
        .where('userId', '==', decodedToken.uid)
        .where('completedAt', '>=', monthStart)
        .where('completedAt', '<=', monthEnd)
        .get();

      let totalAmount = 0;
      let successCount = 0;
      let failedCount = 0;

      snapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.status === 'SUCCESS') {
          totalAmount += data.amount;
          successCount++;
        } else if (data.status === 'FAILED') {
          failedCount++;
        }
      });

      res.status(200).json({
        period: {
          start: monthStart,
          end: monthEnd
        },
        statistics: {
          totalPayments: snapshot.docs.length,
          successfulPayments: successCount,
          failedPayments: failedCount,
          totalAmount: totalAmount.toFixed(2),
          averageAmount: successCount > 0 ? (totalAmount / successCount).toFixed(2) : 0,
          successRate: snapshot.docs.length > 0 ? ((successCount / snapshot.docs.length) * 100).toFixed(2) : 0
        }
      });

    } catch (error) {
      console.error('[ANALYTICS] Error:', error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ===== DATABASE BACKUP (Optional) =====

/**
 * Backup payments to Cloud Storage
 * Run daily to archive payment records
 */
exports.backupPaymentData = onSchedule(
  {
    schedule: "every day 03:00",
    timeoutSeconds: 600
  },
  async (context) => {
    try {
      const storage = admin.storage();
      const bucket = storage.bucket();

      // Export all payments from last day
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const payments = await db
        .collection('payments')
        .where('completedAt', '>=', yesterday)
        .get();

      const data = {
        timestamp: new Date().toISOString(),
        count: payments.docs.length,
        payments: payments.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }))
      };

      const filename = `backups/payments/${new Date().toISOString().split('T')[0]}.json`;
      await bucket.file(filename).save(JSON.stringify(data));

      console.log(`[BACKUP] Saved ${payments.docs.length} payments to ${filename}`);

    } catch (error) {
      console.error('[BACKUP] Error:', error);
    }
  }
);

// ===== ERROR LOGGING & MONITORING =====

/**
 * Log all errors to a dedicated collection for monitoring
 */
async function logPaymentError(functionName, error, context = {}) {
  try {
    await db.collection('payment_errors').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      function: functionName,
      error: {
        message: error.message,
        code: error.code || 'UNKNOWN',
        stack: error.stack
      },
      context: context
    });
  } catch (err) {
    console.error(`[ERROR_LOG] Failed to log error: ${err}`);
  }
}

module.exports = {
  // Payment Functions
  initiatePayment: exports.initiatePayment,
  checkPaymentStatus: exports.checkPaymentStatus,
  processRefund: exports.processRefund,
  paymentCallback: exports.paymentCallback,
  testPaymentFlow: exports.testPaymentFlow,

  // Monitoring
  onPaymentStatusChanged: exports.onPaymentStatusChanged,
  reconcilePendingPayments: exports.reconcilePendingPayments,
  cleanupOldPayments: exports.cleanupOldPayments,

  // API Endpoints
  healthCheck: exports.healthCheck,
  getPaymentAnalytics: exports.getPaymentAnalytics,

  // Backup
  backupPaymentData: exports.backupPaymentData
};
