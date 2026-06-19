import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'dart:io';

Widget buildHybridWebView(WebViewController controller) {
  if (Platform.isAndroid && WebViewPlatform.instance is AndroidWebViewPlatform) {
    return WebViewWidget.fromPlatformCreationParams(
      params: AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
        PlatformWebViewWidgetCreationParams(
          controller: controller.platform,
        ),
        displayWithHybridComposition: true,
      ),
    );
  }
  return WebViewWidget(controller: controller);
}
