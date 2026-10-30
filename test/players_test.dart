import 'package:flutter_test/flutter_test.dart';
import 'package:gruppenspiele/state/players.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Spieler hinzufügen, doppelte und leere Namen ablehnen', () async {
    final players = Players();
    await players.load();

    expect(players.add('Anna'), isTrue);
    expect(players.add('  Ben '), isTrue);
    expect(players.add('anna'), isFalse);
    expect(players.add('   '), isFalse);
    expect(players.names, ['Anna', 'Ben']);

    players.removeAt(0);
    expect(players.names, ['Ben']);
  });
}
