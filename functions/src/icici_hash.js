/**
 * ICICI Secure Hash Generation Utility
 * Production Version: 12.0.0
 * 
 * Rules for ICICI Compliance:
 * 1. Sort keys alphabetically (Case-sensitive UTF-16).
 * 2. Concatenate ONLY values.
 * 3. NO separators, commas, or spaces.
 * 4. HMAC-SHA256 with lowercase hex digest.
 */

"use strict";

const crypto = require("crypto");

/**
 * Generates the secureHash for ICICI requests.
 * @param {Object} payload The request body object.
 * @param {string} secretKey The ICICI Merchant Key.
 * @returns {Object} { hash, plainText, sortedKeys }
 */
function generateSecureHash(payload, secretKey) {
    if (!secretKey) throw new Error("Missing ICICI Merchant Key for hashing.");

    // 1. Filter out existing secureHash if present to avoid recursive hashing
    const filteredPayload = { ...payload };
    delete filteredPayload.secureHash;
    delete filteredPayload.COMMAND_HASH; // For status/refund

    // 2. Sort keys alphabetically
    const sortedKeys = Object.keys(filteredPayload).sort();

    // 3. Concatenate ONLY values (trimmed, stringified)
    const plainText = sortedKeys
        .map(key => {
            const val = filteredPayload[key];
            return (val === null || val === undefined) ? "" : String(val).trim();
        })
        .join("");

    // 4. HMAC SHA256
    const secureHash = crypto
        .createHmac("sha256", secretKey)
        .update(plainText)
        .digest("hex")
        .toLowerCase();

    return { hash: secureHash, plainText, sortedKeys };
}

/**
 * Standard SHA512 for legacy Command APIs if needed
 */
function generateSHA512(rawString) {
    return crypto.createHash("sha512").update(rawString).digest("hex").toLowerCase();
}

module.exports = {
    generateSecureHash,
    generateSHA512
};
