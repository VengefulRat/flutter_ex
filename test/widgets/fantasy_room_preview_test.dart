import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/fantasy_character.dart';
import 'package:lore/models/world.dart';
import 'package:lore/screens/fantasy_room_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('explains how to begin when Sandbox is empty', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: FantasyRoomPreview(backgroundColor: Colors.black),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Create a character in Sandbox to try a sheet.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'back leaves the preview after returning to character selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SandboxStorage.saveCharacters([
        CharacterEntry(id: 'hero', name: 'Griam'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const FantasyRoomPreview(backgroundColor: Colors.black),
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Griam'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('IMPORT FROM SANDBOX'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open preview'), findsOneWidget);
    },
  );

  testWidgets('limits starting class choices without hiding other training', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await SandboxStorage.saveCharacters([
      CharacterEntry(id: 'hero', name: 'Griam'),
    ]);
    await tester.pumpWidget(
      const MaterialApp(
        home: FantasyRoomPreview(backgroundColor: Colors.black),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Griam'));
    await tester.pumpAndSettle();
    final classPicker = find.byKey(const ValueKey('starting-class'));
    await tester.scrollUntilVisible(classPicker, 300);
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.5);
    await tester.pump();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranger').last);
    await tester.pumpAndSettle();
    for (final name in ['animalHandling', 'athletics', 'insight']) {
      final chip = find.byKey(ValueKey('class-skill-$name'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    final fourth = find.byKey(const ValueKey('class-skill-investigation'));
    await tester.ensureVisible(fourth);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(fourth).onSelected, isNull);
    final animalBonus = find.byKey(
      const ValueKey('skill-animalHandling-bonus'),
    );
    await tester.scrollUntilVisible(animalBonus, 300);
    expect(tester.widget<Text>(animalBonus).data, '+2');
    expect(find.textContaining('other sources'), findsOneWidget);
  });

  testWidgets('imports a local character into a temporary skill sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await SandboxStorage.saveCharacters([
      CharacterEntry(id: 'hero', name: 'Griam'),
      CharacterEntry(id: 'other', name: 'Vera'),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: FantasyRoomPreview(backgroundColor: Colors.black),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('not saved, synced or shared'), findsOneWidget);
    await tester.tap(find.text('Griam'));
    await tester.pumpAndSettle();
    expect(find.text('IMPORT FROM SANDBOX'), findsNothing);
    expect(find.text('Vera'), findsNothing);

    await tester.scrollUntilVisible(
      find.byTooltip('Increase Intelligence'),
      300,
    );
    await tester.tap(find.byTooltip('About Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('Especially important for Wizards.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase Intelligence'));
    await tester.tap(find.byTooltip('Increase Intelligence'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('skill-investigation-bonus')),
      300,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('skill-investigation-bonus')))
          .data,
      '+1',
    );
    await tester.tap(
      find.byKey(const ValueKey('skill-investigation-training')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proficient').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('skill-investigation-bonus')))
          .data,
      '+3',
    );
    await tester.scrollUntilVisible(
      find.byTooltip('About Animal Handling'),
      -300,
    );
    await tester.ensureVisible(find.byTooltip('About Animal Handling'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('About Animal Handling'));
    await tester.pumpAndSettle();
    expect(find.text('Often useful for Druids and Rangers.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('IMPORT FROM SANDBOX'), findsOneWidget);
    await tester.tap(find.text('Vera'));
    await tester.pumpAndSettle();
    expect(find.text('Griam'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('IMPORT FROM SANDBOX'), findsOneWidget);
    await tester.tap(find.text('Griam'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('skill-investigation-bonus')),
      300,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('skill-investigation-bonus')))
          .data,
      '+3',
    );
    expect((await SandboxStorage.loadCharacters()).first.name, 'Griam');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ability-score-method')),
      -300,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('ability-score-method'))),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ability-score-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard array').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<AbilityScoreMethod>>(
            find.byKey(const ValueKey('ability-score-method')),
          )
          .value,
      AbilityScoreMethod.standardArray,
    );
    final intelligence = find.byKey(
      const ValueKey('ability-intelligence-array'),
    );
    await tester.scrollUntilVisible(intelligence, 300);
    await tester.tap(intelligence);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(intelligence).value, 15);
    final strength = find.byKey(const ValueKey('ability-strength-array'));
    await tester.scrollUntilVisible(strength, -300);
    expect(tester.widget<DropdownButton<int>>(strength).value, 12);
  });
}
