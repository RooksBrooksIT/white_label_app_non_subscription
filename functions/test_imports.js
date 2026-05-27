const iciciFunctions = require("./src/iciciPaymentFunctions");
console.log("paymentCallback:", typeof iciciFunctions.paymentCallback);
console.log("verifyPayment:", typeof iciciFunctions.verifyPayment);
console.log("processRefund:", typeof iciciFunctions.processRefund);

const { createPaymentSession } = require("./src/createPaymentSession");
console.log("createPaymentSession:", typeof createPaymentSession);
