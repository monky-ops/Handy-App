import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'transport.dart';

/// Öffentlicher MQTT-Vermittler. Kostenlos, ohne Konto. Alle Handys
/// verbinden sich dorthin, egal in welchem Netz sie sind.
const defaultBroker = 'broker.hivemq.com';
const defaultBrokerPort = 1883;

/// Themen pro Lobby:
/// - `<lobby>/up`         Mitspieler → Host (mit `from`)
/// - `<lobby>/to/<id>`    Host → ein Mitspieler
/// - `<lobby>/closed`     Host ist weg
String _lobbyTopic(String code) => 'gruppenspiele-monky/v1/$code';

final _random = Random.secure();

String _randomString(String alphabet, int length) => String.fromCharCodes([
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
    ]);

Future<MqttServerClient> _connect({
  required String broker,
  required int port,
  required String willTopic,
  required Map<String, dynamic> will,
}) async {
  final clientId = 'gs-${_randomString('abcdefghijkmnpqrstuvwxyz23456789', 12)}';
  final client = MqttServerClient.withPort(broker, clientId, port)
    ..logging(on: false)
    ..setProtocolV311()
    ..keepAlivePeriod = 15
    ..connectTimeoutPeriod = 8000
    ..autoReconnect = false
    ..connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic(willTopic)
        .withWillMessage(jsonEncode(will))
        .withWillQos(MqttQos.atMostOnce)
        .startClean();
  try {
    await client.connect();
  } catch (_) {
    client.disconnect();
  }
  if (client.connectionStatus?.state != MqttConnectionState.connected) {
    throw const LobbyException(
        'Keine Verbindung zum Lobby-Server. Hast du Internet?');
  }
  return client;
}

void _publish(MqttServerClient client, String topic, Map<String, dynamic> msg) {
  if (client.connectionStatus?.state != MqttConnectionState.connected) return;
  final payload = MqttClientPayloadBuilder()..addUTF8String(jsonEncode(msg));
  client.publishMessage(topic, MqttQos.atMostOnce, payload.payload!);
}

/// Hört auf [client] und liefert (Thema, JSON) für jede Nachricht.
StreamSubscription<void> _listen(
  MqttServerClient client,
  void Function(String topic, Map<String, dynamic> msg) handler,
) {
  return client.updates!.listen((messages) {
    for (final m in messages) {
      final publish = m.payload as MqttPublishMessage;
      try {
        final text = utf8.decode(publish.payload.message);
        handler(m.topic, jsonDecode(text) as Map<String, dynamic>);
      } catch (_) {
        // Kaputte oder fremde Nachricht – ignorieren.
      }
    }
  });
}

/// Internet: Der Host bekommt einen Code, die anderen treten damit bei.
class InternetHostTransport extends HostTransport {
  InternetHostTransport._(this._client, this.code) {
    _client.subscribe('$_base/up', MqttQos.atMostOnce);
    _subscription = _listen(_client, (topic, msg) {
      final from = msg.remove('from');
      if (from is! String || _dropped.contains(from)) return;
      if (msg['type'] == 'leave') {
        onDisconnect?.call(from);
      } else {
        onMessage?.call(from, msg);
      }
    });
    _client.onDisconnected = () {
      if (!_closing) onLost?.call();
    };
  }

  static Future<InternetHostTransport> start({
    String broker = defaultBroker,
    int port = defaultBrokerPort,
  }) async {
    final code = _randomString(codeAlphabet, codeLength);
    final client = await _connect(
      broker: broker,
      port: port,
      willTopic: '${_lobbyTopic(code)}/closed',
      will: {'type': 'closed'},
    );
    return InternetHostTransport._(client, code);
  }

  final MqttServerClient _client;
  final String code;
  late final StreamSubscription<void> _subscription;
  final _dropped = <String>{};
  bool _closing = false;

  String get _base => _lobbyTopic(code);

  @override
  String get joinCode => encodeInternetCode(code);

  @override
  String? get displayCode => code;

  @override
  void send(String conn, Map<String, dynamic> msg) =>
      _publish(_client, '$_base/to/$conn', msg);

  @override
  void drop(String conn) => _dropped.add(conn);

  @override
  Future<void> close() async {
    _closing = true;
    _publish(_client, '$_base/closed', {'type': 'closed'});
    await _subscription.cancel();
    // Kurz warten, damit die Nachricht noch rausgeht.
    await Future.delayed(const Duration(milliseconds: 200));
    _client.disconnect();
  }
}

class InternetClientTransport extends ClientTransport {
  InternetClientTransport._(this._client, this._code, this._id) {
    _client.subscribe('$_base/to/$_id', MqttQos.atMostOnce);
    _client.subscribe('$_base/closed', MqttQos.atMostOnce);
    _subscription = _listen(_client, (topic, msg) {
      if (topic == '$_base/closed') {
        _finish();
      } else {
        onMessage?.call(msg);
      }
    });
    _client.onDisconnected = _finish;
  }

  static Future<InternetClientTransport> connect(
    InternetTarget target, {
    String broker = defaultBroker,
    int port = defaultBrokerPort,
  }) async {
    final id = _randomString('abcdefghijkmnpqrstuvwxyz23456789', 10);
    final client = await _connect(
      broker: broker,
      port: port,
      willTopic: '${_lobbyTopic(target.code)}/up',
      will: {'type': 'leave', 'from': id},
    );
    return InternetClientTransport._(client, target.code, id);
  }

  final MqttServerClient _client;
  final String _code;
  final String _id;
  late final StreamSubscription<void> _subscription;
  bool _done = false;

  String get _base => _lobbyTopic(_code);

  void _finish() {
    if (_done) return;
    _done = true;
    onDone?.call();
  }

  @override
  void send(Map<String, dynamic> msg) =>
      _publish(_client, '$_base/up', {...msg, 'from': _id});

  @override
  Future<void> close() async {
    send({'type': 'leave'});
    await _subscription.cancel();
    await Future.delayed(const Duration(milliseconds: 200));
    _client.disconnect();
    _finish();
  }
}
