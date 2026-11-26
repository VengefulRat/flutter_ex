import 'dart:math';

String generateUserCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  String part() =>
      List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  return 'LR-${part()}-${part()}';
}
