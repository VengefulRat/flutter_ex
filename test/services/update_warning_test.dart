import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/services/update_service.dart';

void main() {
  for (final accept in [false, true]) {
    testWidgets('Windows installer warning returns $accept', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const WindowsInstallerWarning(),
                );
              },
              child: const Text('Update'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.text('Unsigned Windows installer'), findsOneWidget);
      expect(
        find.textContaining('cannot be verified against tampering'),
        findsOneWidget,
      );
      await tester.tap(find.text(accept ? 'Install anyway' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, accept);
    });
  }
}
