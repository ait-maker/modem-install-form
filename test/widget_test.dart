import 'package:flutter_test/flutter_test.dart';
import 'package:modem_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ModemManagerApp());
    expect(find.text('무선모뎀 신규설치 접수'), findsAny);
  });
}
