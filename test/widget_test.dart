import 'package:flutter_test/flutter_test.dart';
import 'package:rota_verde/main.dart';

void main() {
  testWidgets('Exibe Hello World', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Hello World'), findsOneWidget);
  });
}
