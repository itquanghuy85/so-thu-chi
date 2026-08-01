// Basic smoke test: the app boots without throwing during the first frame.
//
// Full flows (login, workspace creation, transaction posting, etc.) need a
// live backend and are exercised manually per mobile/README.md — this pass
// does not add a mocked-Dio test harness.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';

void main() {
  testWidgets('MoneyFlowApp builds and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoneyFlowApp()));
    await tester.pump();

    expect(find.text('Sổ Thu Chi'), findsOneWidget);
  });
}
