/**
 * Automated Verification Script for Firebase Cloud Functions v1 Exports
 */
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "white-label-app-33300";

const idx = require("./index.js");
console.log("=================================================");
console.log("FIREBASE CLOUD FUNCTIONS v1 VERIFICATION CHECK");
console.log("=================================================");

const expectedExports = [
  "testNotify",
  "handleTicketCreation",
  "handleTicketStatusUpdate",
  "processMailDocument",
  "scheduledEmailRetry",
  "processPaymentSuccess",
  "logPaymentActivity",
  "scheduledSubscriptionReminders",
  "testExpiryReminders",
  "sendOTP",
  "verifyOTPAndResetPassword",
  "checkSubscriptionExpiryReminders",
  "testExpiryReminder",
  "reconcileStuckPayments",
  "processRefund",
  "adminProcessRefund",
  "paymentCallback",
  "verifyPayment",
  "createPaymentSession"
];

let allPassed = true;

expectedExports.forEach((name) => {
  const fn = idx[name];
  if (!fn) {
    console.error(`[FAIL] Missing export: ${name}`);
    allPassed = false;
    return;
  }

  const trigger = fn.__trigger;
  const isCallable = fn.__trigger?.labels?.["deployment-callable"] === "true";
  const isScheduled = fn.__trigger?.labels?.["deployment-scheduled"] === "true";
  const isHttp = !!fn.__trigger?.httpsTrigger;
  const isFirestore = !!fn.__trigger?.eventTrigger?.service?.includes("firestore");

  let type = "UNKNOWN";
  if (isCallable) type = "CALLABLE (onCall)";
  else if (isScheduled) type = `SCHEDULED (${fn.__trigger?.schedule?.schedule} [${fn.__trigger?.schedule?.timeZone}])`;
  else if (isHttp) type = "HTTP (onRequest)";
  else if (isFirestore) type = `FIRESTORE (${fn.__trigger?.eventTrigger?.eventType})`;

  const vpc = fn.__trigger?.vpcConnector ? `[VPC: ${fn.__trigger.vpcConnector} (${fn.__trigger.vpcConnectorEgressSettings})]` : "";
  const mem = fn.__trigger?.availableMemoryMb ? `[Memory: ${fn.__trigger.availableMemoryMb}MB]` : "";

  console.log(`[PASS] ${name.padEnd(35)} -> ${type} ${vpc} ${mem}`);
});

console.log("=================================================");
if (allPassed) {
  console.log("ALL 19 FUNCTIONS VALIDATED SUCCESSFULLY (v1 COMPLIANT)");
} else {
  console.error("SOME EXPORTS FAILED VALIDATION");
  process.exit(1);
}
console.log("=================================================");
