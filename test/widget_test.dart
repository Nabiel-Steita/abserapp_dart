import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:abserapp/main.dart';

void main() {
  testWidgets('App builds and shows splash screen', (WidgetTester tester) async {
    // Create a dummy CameraDescription. In tests, a simple dummy value is sufficient.
    final dummyCamera = CameraDescription(
      name: '0',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    );

    // Pump the MyApp widget with the dummy camera.
    await tester.pumpWidget(MyApp(cameras: [dummyCamera]));

    // Allow any pending frames to complete.
    await tester.pumpAndSettle();

    // Verify that the MaterialApp is in the widget tree.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify that the splash screen (with a CircularProgressIndicator) is present.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
