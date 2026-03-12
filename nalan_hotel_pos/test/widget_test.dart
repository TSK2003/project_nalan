import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalan_hotel_pos/shared/widgets/app_button.dart';

void main() {
  testWidgets('AppButton renders label and handles taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            text: 'Login',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Login'), findsOneWidget);

    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
