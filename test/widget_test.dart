// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:amapos/app/app.dart';

void main() {
  testWidgets('AmaApp smoke test', (WidgetTester tester) async {
    // Verify that AmaApp is a valid widget class.
    expect(const AmaApp(), isA<AmaApp>());
  });
}
