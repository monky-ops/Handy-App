import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gruppenspiele/games/impostor/impostor.dart';
import 'package:gruppenspiele/games/wer_faengt_an/wer_faengt_an.dart';
import 'package:gruppenspiele/lobby/internet_transport.dart';
import 'package:gruppenspiele/lobby/lobby.dart';
import 'package:gruppenspiele/lobby/local_transport.dart';

/// Wartet, bis [condition] auf der Lobby wahr ist.
Future<void> until(Lobby lobby, bool Function() condition) {
  if (condition()) return Future.value();
  final done = Completer<void>();
  void check() {
    if (condition() && !done.isCompleted) done.complete();
  }

  lobby.addListener(check);
  return done.future
      .timeout(const Duration(seconds: 10))
      .whenComplete(() => lobby.removeListener(check));
}

/// Ein ganzer Spielabend: beitreten, Impostor, „Wer fängt an?“, verlassen.
Future<void> playEvening(
  HostLobby host,
  Future<ClientLobby> Function(String name) join,
) async {
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
  await Future.delayed(const Duration(milliseconds: 300));
  expect(chris.view['revealed'], isFalse);

  host.sendAction({'type': 'reveal'});
  await until(chris, () => chris.view['revealed'] == true);
  expect(chris.view['word'], words.single);

  // Während des Spiels kann niemand beitreten.
  await expectLater(join('Zoe'), throwsA(isA<LobbyException>()));

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
  await chris.leave();
  await ben.leave();
}

void main() {
  test('Codes lesen: Lobby-Code, QR-Inhalt, IP', () {
    final net = parseJoinCode(encodeInternetCode('KX7P'));
    expect((net as InternetTarget).code, 'KX7P');
    expect((parseJoinCode(' kx7p ') as InternetTarget).code, 'KX7P');

    final local = parseJoinCode(encodeLocalCode(['192.168.0.5', '10.0.0.2'], 4040))
        as LocalTarget;
    expect(local.hosts, ['192.168.0.5', '10.0.0.2']);
    expect(local.port, 4040);
    expect((parseJoinCode('192.168.43.1') as LocalTarget).port, lobbyPort);

    expect(parseJoinCode('hallo'), isNull);
    expect(parseJoinCode('KX0P'), isNull); // 0 ist nicht im Alphabet
  });

  test('Spielabend im WLAN (direkt)', () async {
    final transport = await LocalHostTransport.start(port: 0);
    final host = HostLobby(transport, 'Anna');
    await playEvening(
      host,
      (name) => ClientLobby.joinTarget(
          LocalTarget(['127.0.0.1'], transport.port), name),
    );
  });

  // Braucht einen MQTT-Vermittler, z. B. lokal:
  //   amqtt -c broker.yaml   und   MQTT_TEST_PORT=1883 flutter test
  final brokerPort = int.tryParse(Platform.environment['MQTT_TEST_PORT'] ?? '');
  test(
    'Spielabend übers Internet (MQTT-Vermittler)',
    skip: brokerPort == null ? 'MQTT_TEST_PORT nicht gesetzt' : false,
    () async {
      const broker = '127.0.0.1';
      final transport =
          await InternetHostTransport.start(broker: broker, port: brokerPort!);
      final host = HostLobby(transport, 'Anna');
      expect(transport.code, hasLength(codeLength));
      await playEvening(
        host,
        (name) => ClientLobby.joinTarget(
          InternetTarget(transport.code),
          name,
          connect: (t) => InternetClientTransport.connect(
            t as InternetTarget,
            broker: broker,
            port: brokerPort,
          ),
        ),
      );

      // Falscher Code: verständliche Meldung statt Hängen.
      await expectLater(
        ClientLobby.joinTarget(
          const InternetTarget('ZZZZ'),
          'Ben',
          connect: (t) => InternetClientTransport.connect(
            t as InternetTarget,
            broker: broker,
            port: brokerPort,
          ),
        ),
        throwsA(isA<LobbyException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('Ohne Host gibt es eine verständliche Meldung', () async {
    await expectLater(
      ClientLobby.joinTarget(const LocalTarget(['127.0.0.1'], 1), 'Ben'),
      throwsA(isA<LobbyException>()),
    );
  });

  test('Spiele haben mindestens einen Modus', () {
    for (final game in [impostor, werFaengtAn]) {
      expect(game.builder != null || game.online != null, isTrue);
    }
  });
}
