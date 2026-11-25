import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/world.dart';
import 'package:lore/services/sandbox_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SandboxStorage.saveWorlds([
      WorldEntry(id: 'w1', name: 'Local world'),
    ]);
    await SandboxStorage.saveCharacters([
      CharacterEntry(id: 'c1', name: 'Local character'),
    ]);
  });

  test('a characters-only cloud snapshot preserves local worlds', () async {
    final snapshot = SandboxPull.fromCloudData({
      'sandboxCharacters': jsonEncode([
        CharacterEntry(id: 'c2', name: 'Cloud character').toJson(),
      ]),
    });
    await snapshot.saveLocally();

    expect((await SandboxStorage.loadWorlds()).single.id, 'w1');
    expect((await SandboxStorage.loadCharacters()).single.id, 'c2');
  });

  test('a worlds-only cloud snapshot preserves local characters', () async {
    final snapshot = SandboxPull.fromCloudData({
      'sandboxWorlds': jsonEncode([
        WorldEntry(id: 'w2', name: 'Cloud world').toJson(),
      ]),
    });
    await snapshot.saveLocally();

    expect((await SandboxStorage.loadWorlds()).single.id, 'w2');
    expect((await SandboxStorage.loadCharacters()).single.id, 'c1');
  });

  test('an explicitly empty cloud list clears only that list', () async {
    await SandboxPull.fromCloudData({'sandboxWorlds': '[]'}).saveLocally();

    expect(await SandboxStorage.loadWorlds(), isEmpty);
    expect((await SandboxStorage.loadCharacters()).single.id, 'c1');
  });

  test('invalid cloud data does not produce a partial snapshot', () async {
    expect(
      () => SandboxPull.fromCloudData({
        'sandboxWorlds': '[]',
        'sandboxCharacters': 'invalid json',
      }),
      throwsFormatException,
    );
    expect((await SandboxStorage.loadWorlds()).single.id, 'w1');
    expect((await SandboxStorage.loadCharacters()).single.id, 'c1');
  });
}
