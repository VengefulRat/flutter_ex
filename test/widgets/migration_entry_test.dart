import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';

void main() {
  test('migration demo is disabled by default', () {
    expect(migrationDemoEnabled, isFalse);
  });
}
