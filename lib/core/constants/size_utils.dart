import 'package:flutter/widgets.dart';

class SizeUtils {
  static bool initialized = false;

  static double deviceWidth = 932;
  static double deviceHeight = 430;

  static double scaleFactor = 1.0;

  static void setScreenSize(BoxConstraints constraints, Orientation orientation) {
    double w = constraints.maxWidth;
    double h = constraints.maxHeight;

    // Convert portrait to landscape virtual space
    if (orientation == Orientation.portrait) {
      final tmp = w;
      w = h;
      h = tmp;
    }

    deviceWidth = w;
    deviceHeight = h;

    // Your Figma design size (LANDSCAPE)
    const double figmaWidth = 932;
    const double figmaHeight = 430;

    final scaleW = deviceWidth / figmaWidth;
    final scaleH = deviceHeight / figmaHeight;

    // Use the smallest to avoid stretched UI
    scaleFactor = scaleW < scaleH ? scaleW : scaleH;

    initialized = true;
  }
}
