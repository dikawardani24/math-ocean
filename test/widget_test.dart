import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/app.dart';
import 'package:math_ocean/core/progress.dart';

void main() {
  testWidgets('the ocean world map shows coral cove and destinations', (
    tester,
  ) async {
    final progress = ProgressController.inMemory();
    await tester.pumpWidget(MathOceanApp(progress: progress));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Coral Cove'), findsOneWidget);
    expect(find.text('Shell Shore'), findsOneWidget);
    expect(find.text('Kelp Forest'), findsOneWidget);
    expect(find.text('Finger Reef'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
