import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/widgets/super_editor_box.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  testWidgets('restores formatting and speaker regions when editing', (
    tester,
  ) async {
    final editorKey = GlobalKey<SuperEditorBoxState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 300,
            child: SuperEditorBox(
              key: editorKey,
              initialText: '  A\nB  ',
              initialRuns: const [
                EditorRun(
                  text: 'A\n',
                  bold: true,
                  color: 0xFFFF0000,
                  size: 18,
                  speaker: 'Alpha',
                ),
                EditorRun(
                  text: 'B',
                  italic: true,
                  color: 0xFF00FF00,
                  size: 16,
                  speaker: 'Beta',
                ),
              ],
              characterColor: Colors.blue,
              characterName: 'Beta',
              onPost: (_, _) {},
            ),
          ),
        ),
      ),
    );

    final runs = editorKey.currentState!.runs;
    expect(editorKey.currentState!.plainText, '  A\nB  ');
    expect(runs.map((run) => run.text).join(), 'A\nB');
    expect(runs.map((run) => run.speaker).toList(), ['Alpha', 'Beta']);
    expect(runs.first.bold, isTrue);
    expect(runs.first.color, 0xFFFF0000);
    expect(runs.first.size, 18);
    expect(runs.last.italic, isTrue);
    expect(runs.last.color, 0xFF00FF00);
    expect(runs.last.size, 16);
    expect(find.text('ALPHA'), findsOneWidget);
    expect(find.text('BETA'), findsOneWidget);
  });

  testWidgets(
    'switching characters inserts an editable box after the current box',
    (tester) async {
      final editorKey = GlobalKey<SuperEditorBoxState>();
      var speaker = 'Griam';
      late StateSetter update;
      String? changedText;
      List<EditorRun>? changedRuns;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 600,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return SuperEditorBox(
                    key: editorKey,
                    initialText: 'Hello ',
                    characterName: speaker,
                    characterColor: Colors.blue,
                    onChanged: (text) => changedText = text,
                    onRunsChanged: (runs) => changedRuns = runs,
                    onPost: (_, _) {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      update(() => speaker = 'Aria');
      await tester.pump();
      await tester.pump();
      expect(find.text('GRIAM'), findsOneWidget);
      expect(find.text('ARIA'), findsOneWidget);
      expect(find.byType(SuperEditor), findsNWidgets(2));
      expect(
        tester.widget<SuperEditor>(find.byType(SuperEditor).at(1)).focusNode!.hasFocus,
        isTrue,
      );

      void typeInEditor(int index, String text) {
        final owner = find.descendant(
          of: find.byType(SuperEditor).at(index),
          matching: find.byElementPredicate(
            (element) =>
                element is StatefulElement && element.state is ImeInputOwner,
          ),
        );
        final client = imeClientGetter(owner);
        final value = client.currentTextEditingValue!;
        final offset = value.selection.extentOffset;
        client.updateEditingValueWithDeltas([
          TextEditingDeltaInsertion(
            oldText: value.text,
            textInserted: text,
            insertionOffset: offset,
            selection: TextSelection.collapsed(offset: offset + text.length),
            composing: TextRange.empty,
          ),
        ]);
      }

      typeInEditor(1, 'world');
      await tester.pump();
      expect(changedText, 'Hello world');
      expect(changedRuns!.map((run) => run.speaker), ['Griam', 'Aria']);
      expect(changedRuns!.map((run) => run.text).join(), 'Hello world');

      final firstEditor = tester.widget<SuperEditor>(
        find.byType(SuperEditor).first,
      );
      firstEditor.focusNode!.requestFocus();
      await tester.pump();
      typeInEditor(0, 'again ');
      await tester.pump();
      expect(changedText, 'Hello again world');
      update(() => speaker = 'Nora');
      await tester.pump();
      await tester.pump();
      final boxes = tester.widgetList<DecoratedSliver>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedSliver &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'character-section-',
              ),
        ),
      );
      expect(boxes.map((box) => (box.key! as ValueKey<String>).value), [
        'character-section-Griam',
        'character-section-Nora',
        'character-section-Aria',
      ]);
      typeInEditor(1, 'new ');
      await tester.pump();
      expect(editorKey.currentState!.plainText, 'Hello again new world');
      expect(editorKey.currentState!.runs.map((run) => run.speaker), [
        'Griam',
        'Nora',
        'Aria',
      ]);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
