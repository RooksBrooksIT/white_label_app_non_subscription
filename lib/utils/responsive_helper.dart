import 'package:flutter/material.dart';

class ResponsiveHelper {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double horizontalPadding;
  static late double verticalPadding;
  static late bool isMobile;
  static late bool isTablet;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;

    isMobile = screenWidth < 600;
    isTablet = screenWidth >= 600 && screenWidth < 1200;
  }

  static double getResponsiveWidth(double percentage) {
    return (percentage / 100) * screenWidth;
  }

  static double getResponsiveHeight(double percentage) {
    return (percentage / 100) * screenHeight;
  }

  static double getResponsiveFontSize(double fontSize) {
    // Base scale on screen width, 375 is a common mobile base width
    double scale = screenWidth / 375.0;
    return fontSize * scale;
  }
}
