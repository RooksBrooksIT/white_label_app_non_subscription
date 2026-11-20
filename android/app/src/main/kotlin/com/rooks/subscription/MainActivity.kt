package com.rooks.subscription

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val UPI_CHANNEL = "com.rooks.subscription/upi_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPI_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchUpiIntent") {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("INVALID_URL", "URL is empty", null)
                    return@setMethodCallHandler
                }

                try {
                    val intent = if (url.startsWith("intent:", ignoreCase = true)) {
                        Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                    } else {
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    }

                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                    // If a specific package is given in the intent (e.g. iMobile or direct app click),
                    // launch it directly.
                    // Otherwise (like for "Other Apps"), create a system chooser so all available UPI
                    // apps (Google Pay, PhonePe, Paytm, BHIM, etc.) are shown to the user.
                    if (!intent.`package`.isNullOrEmpty()) {
                        startActivity(intent)
                    } else {
                        val chooser = Intent.createChooser(intent, "Pay using UPI")
                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(chooser)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    // Fallback 1: Check for browser fallback URL in the intent
                    try {
                        val parsedIntent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                        val fallbackUrl = parsedIntent.getStringExtra("browser_fallback_url")
                        if (!fallbackUrl.isNullOrEmpty()) {
                            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl))
                            browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(browserIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                    } catch (_: Exception) {}

                    // Fallback 2: If it was an intent URL containing UPI params, strip to upi:// and launch
                    try {
                        if (url.contains("pay?")) {
                            val payIndex = url.indexOf("pay?")
                            val endOfParams = if (url.indexOf("#", payIndex) != -1) url.indexOf("#", payIndex) else url.length
                            val upiUri = "upi://${url.substring(payIndex, endOfParams)}"
                            val directIntent = Intent(Intent.ACTION_VIEW, Uri.parse(upiUri))
                            directIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            val chooser = Intent.createChooser(directIntent, "Pay using UPI")
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                    } catch (_: Exception) {}

                    result.error("LAUNCH_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
