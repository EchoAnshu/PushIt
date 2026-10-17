import 'package:flutter_test/flutter_test.dart';
import 'package:pushit_battle/main.dart';

void main() {
  testWidgets('home screen shows the mode buttons', (tester) async {
    await tester.pumpWidget(const PushItApp());
    expect(find.text('Solo Practice'), findsOneWidget);
    expect(find.text('LAN Battle (coming soon)'), findsOneWidget);
  });
}
