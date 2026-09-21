import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tr/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const StyleARApp());
    expect(find.text('StyleAR'), findsWidgets);
  });
}
