import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediTrackApp());
    expect(find.byType(MediTrackApp), findsOneWidget);
  });
}