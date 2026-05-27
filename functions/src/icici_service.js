/**
 * ICICI Payment Service - Production Refactor
 * Version: 12.0.0
 * 
 * Features:
 * - HMAC-SHA256 Alphabetical Hashing
 * - Proper Retry Logic
 * - Secure Header Management
 * - Robust Error Handling
 * - Certification Ready
 */

"use strict";

const axios = require("axios");
const crypto = require("crypto");
const { generateSecureHash, generateSHA512 } = require("./icici_hash");

class ICICIService {
    constructor() {
        this.merchantId = (process.env.ICICI_MERCHANT_MID || "100000000429484").trim();
        this.aggregatorID = (process.env.ICICI_AGGREGATOR_ID || "100000000429483").trim();
        this.merchantKey = (process.env.ICICI_MERCHANT_KEY || "").trim();
        this.baseUrl = (process.env.ICICI_BASE_URL || "https://pgpay.icicibank.com").trim();

        // Correct Production Endpoints (STRICT BANK SPEC) - Priority to Environment Variables
        this.initiateSaleEndpoint = (process.env.ICICI_INITIATE_SALE_URL || `${this.baseUrl}/pg/api/v2/initiateSale`).trim();
        this.generateQrEndpoint = (process.env.ICICI_GENERATE_QR_URL || `${this.baseUrl}/pg/api/generateQR`).trim();
        this.commandEndpoint = (process.env.ICICI_COMMAND_URL || `${this.baseUrl}/pg/api/command`).trim();

        this.returnUrl = (process.env.ICICI_RETURN_URL || "").trim();

        // Production Axios Instance
        this.client = axios.create({
            timeout: 30000,
            validateStatus: () => true, // Handle all status codes manually
            headers: {
                "Accept": "application/json",
                "User-Agent": "Rooks-Tech-Service/12.0"
            }
        });
    }

    /**
     * Helper for Retries
     */
    async _requestWithRetry(config, maxRetries = 2) {
        let lastError;
        for (let i = 0; i <= maxRetries; i++) {
            try {
                const response = await this.client(config);
                // ICICI might return 200 with an error body or a 5xx
                if (response.status >= 500 && i < maxRetries) {
                    console.warn(`[ICICI] Retrying due to status ${response.status} (Attempt ${i + 1})`);
                    await new Promise(r => setTimeout(r, 1000 * (i + 1)));
                    continue;
                }
                return response;
            } catch (err) {
                lastError = err;
                if (i < maxRetries) {
                    await new Promise(r => setTimeout(r, 1000 * (i + 1)));
                    continue;
                }
            }
        }
        throw lastError;
    }

    /**
     * Resolve Endpoint dynamically per payment mode
     */
    _getEndpoint(paymentMode) {
        const cleanBase = this.baseUrl.replace(/\/$/, "");
        if (paymentMode === "UPI") {
            return (process.env.ICICI_GENERATE_QR_URL || `${cleanBase}/tsp/pg/api/generateQR`).trim();
        } else if (paymentMode === "STATUS" || paymentMode === "COMMAND") {
            if (cleanBase.includes("uat")) {
                return `${cleanBase}/tsp/pg/api/command`;
            } else {
                return (process.env.ICICI_COMMAND_URL || `${cleanBase}/pg/api/command`).trim();
            }
        } else {
            // CARD or NETBANKING
            if (cleanBase.includes("uat")) {
                return `${cleanBase}/tsp/pg/api/v2/initiateSale`;
            } else {
                return (process.env.ICICI_INITIATE_SALE_URL || `${cleanBase}/pg/api/v2/initiateSale`).trim();
            }
        }
    }

    /**
     * UPI QR flow - Fully Compliant
     */
    async generateUpiQr({ txnId, amount, email }) {
        const TAG = `[UPI][${txnId}]`;
        const endpointUrl = this._getEndpoint("UPI");
        console.log("PAYMENT MODE:", "UPI");
        console.log("ICICI ENDPOINT:", endpointUrl);
        try {
            const formattedAmount = parseFloat(amount).toFixed(2);

            const payload = {
                merchantId: this.merchantId,
                aggregatorID: this.aggregatorID,
                merchantRefNo: txnId,
                amount: formattedAmount,
                currency: "356",
                emailID: email || "customer@example.com",
                requestType: "UPIQR"
            };

            const hashResult = generateSecureHash(payload, this.merchantKey);
            payload.secureHash = hashResult.hash;

            // Form data formatting
            const params = new URLSearchParams();
            Object.entries(payload).forEach(([k, v]) => params.append(k, v));

            const response = await this._requestWithRetry({
                method: "POST",
                url: endpointUrl,
                data: params.toString(),
                headers: { "Content-Type": "application/x-www-form-urlencoded" }
            });

            return this._parseResponse(response, txnId, "UPI");
        } catch (error) {
            console.error(`${TAG} FATAL:`, error.message);
            return { success: false, error: "Payment Gateway Connectivity Issue" };
        }
    }

    /**
     * CARD/NETBANKING Flow - STRICT BANK SPECIFICATION
     * Updated: 2026-05-20
     */
    async initiateSale({ txnId, amount, email, customerName, customerMobile, paymentMode }) {
        const TAG = `[SALE][${txnId}]`;
        const endpointUrl = this._getEndpoint(paymentMode);
        console.log("PAYMENT MODE:", paymentMode);
        console.log("ICICI ENDPOINT:", endpointUrl);
        try {
            const formattedAmount = parseFloat(amount).toFixed(2);
            const txnDate = this._getISTTimestamp();

            // 1. Build Exact Payload according to ICICI Step-Wise Document
            // Note: payType "0" is used for hosted flow (includes Card & NetBanking)
            let payType = "0";
            if (paymentMode === "NETBANKING") {
                // Ensure correct Netbanking payType exists
                payType = "0";
            }
            const payload = {
                merchantId: this.merchantId,
                aggregatorID: this.aggregatorID,
                merchantTxnNo: txnId,
                amount: formattedAmount,
                currencyCode: "356",
                payType: payType,
                customerEmailID: email || "customer@example.com",
                transactionType: "SALE",
                returnURL: "https://us-central1-white-label-app-33300.cloudfunctions.net/paymentReturn",
                txnDate: txnDate,
                customerMobileNo: customerMobile || "919999999999",
                customerName: (customerName || "Customer").substring(0, 50),
                addlParam1: "000",
                addlParam2: "111"
            };

            // 2. Generate Secure Hash using Alphabetical Sorting logic
            // Rule: Sort keys, concatenate values, HMAC-SHA256
            const hashResult = generateSecureHash(payload, this.merchantKey);
            payload.secureHash = hashResult.hash;

            // 3. Debug Logging for Production Verification
            console.log(`${TAG} --- HASH VERIFICATION ---`);
            console.log(`${TAG} HASH SORTED KEYS:`, JSON.stringify(hashResult.sortedKeys));
            console.log(`${TAG} HASH PLAIN TEXT:`, hashResult.plainText);
            console.log(`${TAG} GENERATED HASH:`, hashResult.hash);
            console.log(`${TAG} FINAL PAYLOAD:`, JSON.stringify(payload));

            // 4. API Execution
            const response = await this._requestWithRetry({
                method: "POST",
                url: endpointUrl,
                data: payload,
                headers: { "Content-Type": "application/json" }
            });

            console.log(`${TAG} ICICI RAW RESPONSE:`, JSON.stringify(response.data));

            const data = response.data;
            if (data.responseCode === "R1000" || data.RESPONSE_CODE === "R1000") {
                // Success - Build redirect URL according to Step 6
                // redirectURI?tranCtx=value
                const redirectURI = data.redirectURI || data.REDIRECT_URI || data.redirectUri;
                const tranCtx = data.tranCtx || data.TRAN_CTX;

                if (redirectURI && tranCtx) {
                    const redirectUrl = `${redirectURI}?tranCtx=${tranCtx}`;
                    return {
                        success: true,
                        redirectUrl: redirectUrl,
                        txnId,
                        raw: data
                    };
                }
            }

            // Handle Failures
            const errorMsg = data.responseDescription || data.message || data.RESPONSE_MESSAGE || "Initiate Sale Failed";
            console.error(`${TAG} ICICI ERROR:`, errorMsg, data);
            return { success: false, error: errorMsg, raw: data };

        } catch (error) {
            console.error(`${TAG} FATAL:`, error.message);
            return { success: false, error: error.message };
        }
    }

    /**
     * Corrected Status Check API - STRICT BANK SPECIFICATION
     */
    async statusCheck(txnId) {
        const TAG = `[STATUS][${txnId}]`;
        const statusUrl = this._getEndpoint("STATUS");
        try {
            const payload = {
                merchantId: this.merchantId,
                aggregatorID: this.aggregatorID,
                merchantTxnNo: txnId,
                originalTxnNo: txnId,
                transactionType: "STATUS"
            };

            const hashResult = generateSecureHash(payload, this.merchantKey);
            payload.secureHash = hashResult.hash;

            console.log("STATUS ENDPOINT:", statusUrl);
            console.log("STATUS REQUEST PAYLOAD:", payload);

            const response = await this._requestWithRetry({
                method: "POST",
                url: statusUrl,
                data: payload,
                headers: { "Content-Type": "application/json" }
            });

            console.log("STATUS RAW RESPONSE:", response.data);

            if (response.status === 200) {
                return { success: true, data: response.data };
            }
            return { success: false, error: `HTTP ${response.status}`, data: response.data };
        } catch (error) {
            console.error(`${TAG} Exception:`, error.message);
            return { success: false, error: error.message };
        }
    }

    /**
     * Refund API
     */
    async processRefund(txnId, refundAmount) {
        const TAG = `[REFUND][${txnId}]`;
        const refundUrl = this._getEndpoint("STATUS");
        try {
            const payload = {
                MID: this.merchantId,
                AGGREGATOR_ID: this.aggregatorID,
                ORDER_ID: txnId,
                AMOUNT: parseFloat(refundAmount).toFixed(2),
                COMMAND: "REFUND",
                TXN_DATE: this._getISTTimestamp()
            };

            const raw = [payload.MID, payload.ORDER_ID, payload.AMOUNT, payload.COMMAND, this.merchantKey].join("|");
            payload.COMMAND_HASH = generateSHA512(raw);

            console.log("REFUND ENDPOINT:", refundUrl);
            console.log("REFUND REQUEST PAYLOAD:", payload);

            const response = await this._requestWithRetry({
                method: "POST",
                url: refundUrl,
                data: payload,
                headers: { "Content-Type": "application/json" }
            });

            console.log("REFUND RAW RESPONSE:", response.data);

            if (response.status === 200) {
                const data = response.data;
                const isSuccess = (data?.RESPONSE_CODE === "0" || data?.responseCode === "0");
                return { success: isSuccess, data: response.data };
            }
            return { success: false, error: `HTTP ${response.status}` };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Unified Response Parser
     */
    _parseResponse(response, txnId, mode) {
        const data = response.data;

        // Handle HTTP errors
        if (response.status !== 200) {
            return { success: false, error: `Gateway returned HTTP ${response.status}`, raw: data };
        }

        // Logic for returnCode (UPI) vs responseCode (SALE)
        const returnCode = data?.respHeader?.returnCode || data?.responseCode || data?.status;
        const isSuccess = (returnCode == "200" || returnCode == "0" || returnCode == "SUCCESS" || returnCode == "00");

        if (isSuccess) {
            const upiUrl = data?.respBody?.upiQR || data?.respBody?.bharatQR;
            const redirectUrl = data?.paymentPageUrl || data?.respBody?.paymentPageUrl;

            return {
                success: true,
                txnId,
                upiUrl: upiUrl || null,
                redirectUrl: redirectUrl || upiUrl || null
            };
        }

        const errorMsg = data?.respHeader?.desc || data?.message || data?.errorMsg || "Transaction Rejected";
        return { success: false, error: errorMsg, raw: data };
    }

    _getISTTimestamp() {
        const ist = new Date(new Date().getTime() + (5.5 * 60 * 60 * 1000));
        const pad = (n) => String(n).padStart(2, "0");
        return `${ist.getUTCFullYear()}${pad(ist.getUTCMonth() + 1)}${pad(ist.getUTCDate())}${pad(ist.getUTCHours())}${pad(ist.getUTCMinutes())}${pad(ist.getUTCSeconds())}`;
    }
}

module.exports = new ICICIService();
