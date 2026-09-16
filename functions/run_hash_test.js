const fs = require('fs');
const path = require('path');

// Parse .env manually
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split('\n').forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
            const parts = trimmed.split('=');
            if (parts.length >= 2) {
                const key = parts[0].trim();
                const value = parts.slice(1).join('=').trim();
                process.env[key] = value;
            }
        }
    });
}

console.log("Loaded environment variables:");
console.log("MID:", process.env.ICICI_MERCHANT_MID);
console.log("Key:", process.env.ICICI_MERCHANT_KEY ? "EXISTS (len " + process.env.ICICI_MERCHANT_KEY.length + ")" : "MISSING");

const iciciService = require('./src/icici_service');

