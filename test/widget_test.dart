import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/app.dart';
import 'package:math_ocean/core/progress.dart';

void main() {
  testWidgets('the ocean home shows the brand and the reef map', (tester) async {
    final progress = ProgressController.inMemory();
    await tester.pumpWidget(MathOceanApp(progress: progress));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Math Rings'), findsOneWidget);
    expect(find.text('OCEAN NUMBERLAND'), findsOneWidget);
    expect(find.text('The reef map'), findsOneWidget);
    expect(find.text('Coral Cove'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
