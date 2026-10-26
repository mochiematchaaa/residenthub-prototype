import 'package:flutter_test/flutter_test.dart';

import 'package:residenthub_dashboard/main.dart';

void main() {
  testWidgets('shows a start-up screen while the last sign-in is checked', (tester) async {
    await tester.pumpWidget(const ResidentHubApp());
    await tester.pump();
    expect(find.text('ResidentHub'), findsOneWidget);
  });
}
