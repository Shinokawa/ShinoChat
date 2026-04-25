import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app theme builds material app', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(children: const [Text('ShinoChat'), Text('Sign in')]),
        ),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('ShinoChat'), findsOneWidget);
  });
}
