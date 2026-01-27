import 'package:flutter/widgets.dart';
import 'size_utils.dart';

class Sizer extends StatelessWidget {
  final Widget Function(BuildContext context, Orientation orientation) builder;

  const Sizer({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OrientationBuilder(
          builder: (context, orientation) {
            SizeUtils.setScreenSize(constraints, orientation);
            return builder(context, orientation);
          },
        );
      },
    );
  }
}
