import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/fantasy_character.dart';
import 'package:lore/models/fantasy_equipment.dart';
import 'package:lore/models/world.dart';
import 'package:lore/screens/fantasy_room_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Necromancer spellbook and Grim Harvest preview work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await SandboxStorage.saveCharacters([
      CharacterEntry(id: 'hero', name: 'Althea'),
    ]);
    await tester.pumpWidget(
      const MaterialApp(
        home: FantasyRoomPreview(backgroundColor: Colors.black),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Althea'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Increase level'));
      await tester.pump();
    }
    final classPicker = find.byKey(const ValueKey('starting-class'));
    await tester.scrollUntilVisible(classPicker, 300);
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Wizard'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Wizard').last);
    await tester.pumpAndSettle();
    final subclass = find.byKey(const ValueKey('subclass'));
    await tester.ensureVisible(subclass);
    await tester.pumpAndSettle();
    await tester.tap(subclass);
    await tester.pumpAndSettle();
    await tester.tap(find.text('School of Necromancy (2014 legacy)').last);
    await tester.pumpAndSettle();

    final book = find.byKey(const ValueKey('edit-spellbook'));
    await tester.scrollUntilVisible(book, 200);
    expect(find.textContaining('Spellbook: 1 spell.'), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(book), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-search')),
      'fireball',
    );
    await tester.pumpAndSettle();
    final fireball = find.byKey(const ValueKey('spell-spellbook-fireball'));
    expect(tester.widget<CheckboxListTile>(fireball).onChanged, isNotNull);
    await tester.tap(fireball);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(book, -100);
    expect(find.textContaining('Spellbook: 2 spells.'), findsOneWidget);

    final damage = find.byKey(const ValueKey('take-damage'));
    await tester.scrollUntilVisible(damage, 200);
    await Scrollable.ensureVisible(tester.element(damage), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(damage);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hit-points-amount')),
      '5',
    );
    await tester.tap(find.byKey(const ValueKey('hit-points-confirm')));
    await tester.pumpAndSettle();

    final abilities = find.byKey(const ValueKey('necromancer-abilities'));
    await tester.scrollUntilVisible(abilities, 150);
    await Scrollable.ensureVisible(tester.element(abilities), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(abilities);
    await tester.pumpAndSettle();
    final harvest = find.byKey(const ValueKey('grim-harvest'));
    await tester.scrollUntilVisible(harvest, 150);
    await Scrollable.ensureVisible(tester.element(harvest), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(harvest);
    await tester.pumpAndSettle();
    final apply = find.byKey(const ValueKey('grim-harvest-apply'));
    expect(tester.widget<TextButton>(apply).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('grim-harvest-necromancy')));
    await tester.tap(find.byKey(const ValueKey('grim-harvest-confirm-kill')));
    await tester.pumpAndSettle();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(harvest).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('grim-harvest-new-turn')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(harvest).onPressed, isNotNull);
    final total = find.byKey(const ValueKey('hit-points-total'));
    await tester.scrollUntilVisible(total, -150);
    expect(tester.widget<Text>(total).data, '24 / 26 HP');
    final increase = find.byTooltip('Increase level');
    await tester.scrollUntilVisible(increase, -300);
    for (var i = 0; i < 4; i++) {
      await tester.tap(increase);
      await tester.pump();
    }
    await tester.scrollUntilVisible(damage, 300);
    await Scrollable.ensureVisible(tester.element(damage), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(damage);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('hit-points-amount')),
      '7',
    );
    await tester.tap(find.byKey(const ValueKey('necrotic-damage')));
    await tester.tap(find.byKey(const ValueKey('hit-points-confirm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(total, -150);
    expect(tester.widget<Text>(total).data, '21 / 42 HP');
  });

  testWidgets('spell picker shows unavailable spells and prepared choices', (
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
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleric').last);
    await tester.pumpAndSettle();

    final spellAttack = find.byKey(const ValueKey('spell-attack-bonus'));
    final spellDc = find.byKey(const ValueKey('spell-save-dc'));
    await tester.scrollUntilVisible(spellAttack, 200);
    expect(tester.widget<Text>(spellAttack).data, 'Spell attack: +2');
    expect(tester.widget<Text>(spellDc).data, 'Spell save DC: 10');
    final increaseWisdom = find.byTooltip('Increase Wisdom');
    await tester.scrollUntilVisible(increaseWisdom, -200);
    await tester.tap(increaseWisdom);
    await tester.tap(increaseWisdom);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(spellAttack, 200);
    expect(tester.widget<Text>(spellAttack).data, 'Spell attack: +3');
    expect(tester.widget<Text>(spellDc).data, 'Spell save DC: 11');

    final slots = find.byKey(const ValueKey('spell-slots'));
    await tester.scrollUntilVisible(slots, 200);
    await Scrollable.ensureVisible(tester.element(slots), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(slots);
    await tester.pumpAndSettle();
    final slotCount = find.byKey(const ValueKey('spell-slots-1'));
    final useSlot = find.byKey(const ValueKey('expend-slot-1'));
    final undoSlot = find.byKey(const ValueKey('restore-slot-1'));
    await tester.scrollUntilVisible(useSlot, 150);
    expect(tester.widget<Text>(slotCount).data, 'Level 1: 2 / 2');
    await tester.tap(useSlot);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(slotCount).data, 'Level 1: 1 / 2');
    await tester.tap(undoSlot);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(slotCount).data, 'Level 1: 2 / 2');
    await tester.tap(useSlot);
    await tester.pumpAndSettle();
    final longRest = find.byKey(const ValueKey('long-rest-slots'));
    await tester.scrollUntilVisible(longRest, 150);
    await tester.tap(longRest);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(slotCount).data, 'Level 1: 2 / 2');
    expect(find.byKey(const ValueKey('short-rest-slots')), findsNothing);
    final slotTitle = find.text('Spell slots');
    await tester.scrollUntilVisible(slotTitle, -150);
    await Scrollable.ensureVisible(tester.element(slotTitle), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(slotTitle);
    await tester.pumpAndSettle();

    final prepare = find.byKey(const ValueKey('prepare-spells'));
    await tester.scrollUntilVisible(prepare, 200);
    await tester.tap(prepare);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('spell-search'));
    await tester.enterText(search, 'aid');
    await tester.pumpAndSettle();
    final aid = find.byKey(const ValueKey('spell-prepared-aid'));
    expect(tester.widget<CheckboxListTile>(aid).onChanged, isNull);
    expect(
      find.textContaining('Requires a higher-level spell slot.'),
      findsOneWidget,
    );
    await tester.enterText(search, 'bless');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-prepared-bless')));
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Prepared: Bless'), -100);
    expect(find.text('Prepared: Bless'), findsOneWidget);
    expect(find.text('1 / 4 prepared spells'), findsOneWidget);
  });

  testWidgets('Warlock pact slots recover on a short rest', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await SandboxStorage.saveCharacters([
      CharacterEntry(id: 'hero', name: 'Pact hero'),
    ]);
    await tester.pumpWidget(
      const MaterialApp(
        home: FantasyRoomPreview(backgroundColor: Colors.black),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pact hero'));
    await tester.pumpAndSettle();
    final classPicker = find.byKey(const ValueKey('starting-class'));
    await tester.scrollUntilVisible(classPicker, 300);
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Warlock').last,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Warlock').last),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warlock').last);
    await tester.pumpAndSettle();
    final slots = find.byKey(const ValueKey('spell-slots'));
    await tester.scrollUntilVisible(slots, 200);
    await Scrollable.ensureVisible(tester.element(slots), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(slots);
    await tester.pumpAndSettle();
    final useSlot = find.byKey(const ValueKey('expend-slot-1'));
    final count = find.byKey(const ValueKey('spell-slots-1'));
    await tester.scrollUntilVisible(useSlot, 150);
    await tester.tap(useSlot);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, 'Level 1: 0 / 1');
    expect(tester.widget<OutlinedButton>(useSlot).onPressed, isNull);
    final shortRest = find.byKey(const ValueKey('short-rest-slots'));
    await tester.scrollUntilVisible(shortRest, 150);
    await tester.tap(shortRest);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, 'Level 1: 1 / 1');
  });

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
      await tester.scrollUntilVisible(chip, 150);
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

  testWidgets('background bonuses update scores and skill modifiers', (
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
    final background = find.byKey(const ValueKey('background'));
    await tester.scrollUntilVisible(background, 200);
    await Scrollable.ensureVisible(tester.element(background), alignment: 0.3);
    await tester.pump();
    await tester.tap(background);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sage').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Background feats, tools and equipment'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('background-skills'))).data,
      'Skills: Arcana, History',
    );
    final plusTwo = find.byKey(const ValueKey('background-plus-2'));
    await tester.ensureVisible(plusTwo);
    await tester.pumpAndSettle();
    await tester.tap(plusTwo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intelligence').last);
    await tester.pumpAndSettle();
    final total = find.byKey(const ValueKey('ability-intelligence-total'));
    await tester.scrollUntilVisible(total, 250);
    expect(
      tester.widget<Text>(total).data,
      'Intelligence: 10 base + 2 background = 12',
    );
    final skill = find.byKey(const ValueKey('skill-investigation-bonus'));
    await tester.scrollUntilVisible(skill, 300);
    expect(tester.widget<Text>(skill).data, '+1');

    final method = find.byKey(const ValueKey('background-method'));
    await tester.scrollUntilVisible(method, -250);
    await Scrollable.ensureVisible(tester.element(method), alignment: 0.3);
    await tester.pump();
    await tester.tap(method);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1 to each').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(total, 250);
    expect(
      tester.widget<Text>(total).data,
      'Intelligence: 10 base + 1 background = 11',
    );
    await tester.scrollUntilVisible(skill, 300);
    expect(tester.widget<Text>(skill).data, '+0');
  });

  testWidgets('background skills replace overlapping class choices', (
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
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleric').last);
    await tester.pumpAndSettle();
    final history = find.byKey(const ValueKey('class-skill-history'));
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(history).selected, isTrue);

    final background = find.byKey(const ValueKey('background'));
    await tester.scrollUntilVisible(background, -300);
    await Scrollable.ensureVisible(tester.element(background), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(background);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sage').last);
    await tester.pumpAndSettle();

    final count = find.text('Starting class skills: 0 of 2 selected');
    await tester.scrollUntilVisible(count, 300);
    expect(count, findsOneWidget);
    await tester.scrollUntilVisible(history, 300);
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(history).selected, isFalse);
    expect(tester.widget<FilterChip>(history).onSelected, isNull);
    expect(find.text('History (background)'), findsOneWidget);
    final bonus = find.byKey(const ValueKey('skill-history-bonus'));
    await tester.scrollUntilVisible(bonus, 300);
    expect(tester.widget<Text>(bonus).data, '+2');
  });

  testWidgets('equipment preview updates armor class and training', (
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
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleric').last);
    await tester.pumpAndSettle();

    final weapon = find.byKey(const ValueKey('equipment-weapon'));
    await tester.scrollUntilVisible(weapon, 400);
    await Scrollable.ensureVisible(tester.element(weapon), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(weapon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dagger (simple)').last);
    await tester.pumpAndSettle();
    expect(find.text('Proficient from starting class.'), findsOneWidget);

    final armor = find.byKey(const ValueKey('equipment-armor'));
    await tester.scrollUntilVisible(armor, 300);
    await Scrollable.ensureVisible(tester.element(armor), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(armor);
    await tester.pumpAndSettle();
    final chainOption = find.ancestor(
      of: find.text('Chain Shirt (medium)').last,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem &&
            widget.value == FantasyArmor.chainShirt,
      ),
    );
    expect(
      find.descendant(of: chainOption, matching: find.text('Trained')),
      findsOneWidget,
    );
    await tester.tap(find.text('Chain Shirt (medium)').last);
    await tester.pumpAndSettle();
    final shield = find.byKey(const ValueKey('equipment-shield'));
    await tester.ensureVisible(shield);
    await tester.pumpAndSettle();
    await tester.tap(shield);
    await tester.pumpAndSettle();
    final ac = find.byKey(const ValueKey('equipment-armor-class'));
    await tester.ensureVisible(ac);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(ac).data, 'Armor class: 15');

    await tester.scrollUntilVisible(classPicker, -400);
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bard').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(ac, 400);
    expect(tester.widget<Text>(ac).data, 'Armor class: 13');
    expect(find.textContaining('No shield training'), findsOneWidget);
    expect(
      find.textContaining('No training from starting class'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(armor, -200);
    await Scrollable.ensureVisible(tester.element(armor), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(armor);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chainOption, matching: find.text('Untrained')),
      findsOneWidget,
    );
    await tester.tap(find.text('Chain Shirt (medium)').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No training from starting class'),
      findsOneWidget,
    );
  });

  testWidgets('damage and healing update temporary hit points', (tester) async {
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
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fighter').last);
    await tester.pumpAndSettle();

    final total = find.byKey(const ValueKey('hit-points-total'));
    await tester.scrollUntilVisible(total, 250);
    expect(tester.widget<Text>(total).data, '10 / 10 HP');
    final damage = find.byKey(const ValueKey('take-damage'));
    await tester.scrollUntilVisible(damage, 150);
    await tester.pumpAndSettle();
    await tester.tap(damage);
    await tester.pumpAndSettle();
    final amount = find.byKey(const ValueKey('hit-points-amount'));
    final confirm = find.byKey(const ValueKey('hit-points-confirm'));
    await tester.enterText(amount, '-3');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive whole number.'), findsOneWidget);
    await tester.enterText(amount, '3');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(total, -150);
    expect(tester.widget<Text>(total).data, '7 / 10 HP');

    final heal = find.byKey(const ValueKey('heal'));
    await tester.scrollUntilVisible(heal, 150);
    await tester.pumpAndSettle();
    await tester.tap(heal);
    await tester.pumpAndSettle();
    await tester.enterText(amount, '99');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(heal, -150);
    expect(tester.widget<OutlinedButton>(heal).onPressed, isNull);
    await tester.scrollUntilVisible(total, -150);
    expect(tester.widget<Text>(total).data, '10 / 10 HP');
  });

  testWidgets('heavy weapon warnings are visible before selection', (
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
    await Scrollable.ensureVisible(tester.element(classPicker), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(classPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fighter').last);
    await tester.pumpAndSettle();

    final weapon = find.byKey(const ValueKey('equipment-weapon'));
    await tester.scrollUntilVisible(weapon, 400);
    await Scrollable.ensureVisible(tester.element(weapon), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(weapon);
    await tester.pumpAndSettle();
    final greatsword = find.text('Greatsword (martial)');
    await tester.scrollUntilVisible(
      greatsword,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final option = find.ancestor(
      of: greatsword,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem &&
            widget.value == FantasyWeapon.greatsword,
      ),
    );
    expect(
      find.descendant(of: option, matching: find.text('Low Str · Trained')),
      findsOneWidget,
    );
    await tester.tap(greatsword);
    await tester.pumpAndSettle();
    final attack = find.byKey(const ValueKey('weapon-attack-strength'));
    await tester.scrollUntilVisible(attack, 150);
    expect(
      tester.widget<Text>(attack).data,
      'Strength: attack +2; damage modifier +0',
    );
    expect(
      find.byKey(const ValueKey('weapon-attack-disadvantage')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('equipment-heavy-requirement')),
      150,
    );
    expect(
      find.textContaining('Strength 13 is needed to avoid disadvantage'),
      findsOneWidget,
    );
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('skill-investigation-training')),
    );
    await tester.pumpAndSettle();
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
