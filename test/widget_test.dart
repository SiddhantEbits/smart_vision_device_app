import 'package:flutter_test/flutter_test.dart';
import 'package:smart_vision_device_app/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartVisionApp());
    
    // Basic verification that the app starts
    expect(find.byType(SmartVisionApp), findsOneWidget);
  });
}
