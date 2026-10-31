import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gruppenspiele/games/impostor/impostor.dart';
import 'package:gruppenspiele/games/wer_faengt_an/wer_faengt_an.dart';
import 'package:gruppenspiele/lobby/lobby.dart';

/// Wartet, bis [condition] auf der Lobby wahr ist.
Future<void> until(Lobby lobby, bool Function() condition) {
  if (condition()) return Future.value();
  final done = Completer<void>();
  void check() {
    if (condition() && !done.isCompleted) done.complete();
  }

  lobby.addListener(check);
  return done.future
      .timeout(const Duration(seconds: 5))
      .whenComplete(() => lobby.removeListener(check));
}

void main() {
  test('Join-Code hin und zurück', () {
    final code = encodeJoinCode(['192.168.0.5', '10.0.0.2'], 4040);
    final parsed = parseJoinCode(code)!;
    expect(parsed.hosts, ['192.168.0.5', '10.0.0.2']);
    expect(parsed.port, 4040);

    expect(parseJoinCode(' 192.168.43.1 ')!.port, lobbyPort);
    expect(parseJoinCode('hallo'), isNull);
  });

  test('Host und Mitspieler spielen Impostor über das Netzwerk', () async {
    final host = await HostLobby.start('Anna', port: 0);
    addTearDown(host.leave);

    Future<ClientLobby> join(String name) async {
      final c = await ClientLobby.join(['127.0.0.1'], host.port, name);
      addTearDown(c.leave);
      return c;
    }

    final ben = await join('Ben');
    final chris = await join('Chris');
    final ben2 = await join('Ben'); // doppelter Name wird umbenannt

    await until(ben, () => ben.players.length == 4);
    expect(
      [for (final p in ben.players) p.name],
      ['Anna', 'Ben', 'Chris', 'Ben 2'],
    );

    host.startGame(impostor);
    final clients = [ben, chris, ben2];
    for (final c in clients) {
      await until(c, () => c.gameName == 'Impostor');
    }

    // Genau einer ist Impostor und nur der kennt das Wort nicht.
    final views = [host.view, for (final c in clients) c.view];
    final impostors = views.where((v) => v['isImpostor'] == true).toList();
    expect(impostors, hasLength(1));
    expect(impostors.single.containsKey('word'), isFalse);
    final words = views
        .where((v) => v['isImpostor'] != true)
        .map((v) => v['word'])
        .toSet();
    expect(words, hasLength(1));

    // Mitspieler dürfen nicht auflösen, der Host schon.
    ben.sendAction({'type': 'reveal'});
    await Future.delayed(const Duration(milliseconds: 200));
    expect(chris.view['revealed'], isFalse);

    host.sendAction({'type': 'reveal'});
    await until(chris, () => chris.view['revealed'] == true);
    expect(chris.view['word'], words.single);

    // Während des Spiels kann niemand beitreten.
    await expectLater(
      ClientLobby.join(['127.0.0.1'], host.port, 'Zoe'),
      throwsA(isA<LobbyException>()),
    );

    // Zurück in die Lobby, dann „Wer fängt an?“ – jeder darf auslosen.
    host.endGame();
    await until(ben, () => ben.gameName == null);
    host.startGame(werFaengtAn);
    await until(chris, () => chris.gameName == werFaengtAn.name);
    chris.sendAction({'type': 'roll'});
    await until(ben, () => ben.view['roll'] == 1);
    await until(chris, () => chris.view['roll'] == 1);
    expect(ben.view['result'], isNotNull);
    expect(chris.view['result'], ben.view['result']);
    expect(host.view['result'], ben.view['result']);

    // Ein Mitspieler geht, der Host sieht es.
    await ben2.leave();
    await until(host, () => host.players.length == 3);

    // Host schließt die Lobby, die anderen merken es.
    await host.leave();
    await until(ben, () => ben.closedReason != null);
  });

  test('Beitritt ohne Host schlägt mit verständlicher Meldung fehl', () async {
    await expectLater(
      ClientLobby.join(['127.0.0.1'], 1, 'Ben'),
      throwsA(isA<LobbyException>()),
    );
  });

  test('Spiele haben mindestens einen Modus', () {
    for (final game in [impostor, werFaengtAn]) {
      expect(game.builder != null || game.online != null, isTrue);
    }
  });
}
