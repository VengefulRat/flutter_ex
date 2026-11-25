import 'package:flutter_test/flutter_test.dart';
import 'package:lore/screens/diary_screen.dart';

void main() {
  test(
    'uses the newest diary version and retains entries from both devices',
    () {
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 1, 2);
      final local = [
        DiaryEntry(id: 'remote-newer', title: 'old local', updatedAt: older),
        DiaryEntry(id: 'local-newer', title: 'new local', updatedAt: newer),
        DiaryEntry(id: 'local-only', updatedAt: older),
      ];
      final remote = [
        DiaryEntry(id: 'remote-newer', title: 'new remote', updatedAt: newer),
        DiaryEntry(id: 'local-newer', title: 'old remote', updatedAt: older),
        DiaryEntry(id: 'remote-only', updatedAt: newer),
      ];

      final merged = DiaryStorage.mergeEntries(local, remote);
      final byId = {for (final entry in merged) entry.id: entry};

      expect(
        byId.keys,
        containsAll([
          'remote-newer',
          'local-newer',
          'local-only',
          'remote-only',
        ]),
      );
      expect(byId.length, 4);
      expect(byId['remote-newer']!.title, 'new remote');
      expect(byId['local-newer']!.title, 'new local');
      expect(merged.first.updatedAt, newer);
      expect(merged.last.updatedAt, older);
    },
  );

  test('keeps the local diary version when timestamps are equal', () {
    final time = DateTime.utc(2026, 1, 1);
    final merged = DiaryStorage.mergeEntries(
      [DiaryEntry(id: 'same', title: 'local', updatedAt: time)],
      [DiaryEntry(id: 'same', title: 'remote', updatedAt: time)],
    );

    expect(merged.single.title, 'local');
  });
}
