import 'size_utils.dart';

extension ResponsiveNum on num {
  double get adaptSize {
    if (!SizeUtils.initialized) return toDouble();
    return this * SizeUtils.scaleFactor;
  }
}
