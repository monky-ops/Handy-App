import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../games/game.dart';
import '../games/registry.dart';

/// Port, auf dem das Host-Handy die Lobby anbietet.
const lobbyPort = 4040;

const _qrPrefix = 'gruppenspiele:';

/// Eine Lobby aus Sicht dieses Handys – egal ob Host oder Mitspieler.
///
/// Nachrichten (JSON über WebSocket):
/// - Mitspieler → Host: `join {name}`, `action {data}`
/// - Host → Mitspieler: `welcome {id}`, `state {players, game, view}`,
///   `error {message}`
abstract class Lobby extends ChangeNotifier {
  String get myId;
  bool get isHost;
  List<LobbyPlayer> get players;

  /// Name des laufenden Spiels, oder null, wenn alle in der Lobby warten.
  String? get gameName;

  /// Die Ansicht des laufenden Spiels für dieses Handy.
  Map<String, dynamic> get view;

  /// Gesetzt, wenn die Verbindung beendet wurde (mit Grund).
  String? get closedReason;

  Game? get game =>
      allGames.where((g) => g.name == gameName).firstOrNull;

  void sendAction(Map<String, dynamic> action);

  Future<void> leave();

  // Netzwerk-Events können nach dem Verlassen noch eintreffen.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}

class LobbyException implements Exception {
  const LobbyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Inhalt des QR-Codes: alle Adressen des Hosts plus Port.
String encodeJoinCode(List<String> addresses, int port) =>
    '$_qrPrefix${addresses.join(',')}:$port';

/// Liest einen QR-Code oder eine eingetippte IP. Gibt null zurück,
/// wenn es keine gültige Angabe ist.
({List<String> hosts, int port})? parseJoinCode(String input) {
  var text = input.trim();
  if (text.startsWith(_qrPrefix)) text = text.substring(_qrPrefix.length);
  if (text.isEmpty) return null;

  var port = lobbyPort;
  final colon = text.lastIndexOf(':');
  if (colon != -1) {
    final parsed = int.tryParse(text.substring(colon + 1));
    if (parsed == null) return null;
    port = parsed;
    text = text.substring(0, colon);
  }
  final hosts = text
      .split(',')
      .map((h) => h.trim())
      .where((h) => InternetAddress.tryParse(h) != null)
      .toList();
  if (hosts.isEmpty) return null;
  return (hosts: hosts, port: port);
}

/// IPv4-Adressen dieses Handys, WLAN/Hotspot-typische zuerst.
Future<List<String>> localAddresses() async {
  final interfaces =
      await NetworkInterface.list(type: InternetAddressType.IPv4);
  final result = [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.isLoopback) a.address,
  ];
  int rank(String ip) => ip.startsWith('192.168.')
      ? 0
      : ip.startsWith('172.')
          ? 1
          : ip.startsWith('10.')
              ? 2
              : 3;
  result.sort((a, b) => rank(a).compareTo(rank(b)));
  return result;
}

/// Lobby auf dem eigenen Handy: startet einen kleinen WebSocket-Server,
/// verwaltet die Spieler und lässt die Spiellogik laufen.
class HostLobby extends Lobby {
  HostLobby._(this._server, this.addresses, String name) {
    _players.add(LobbyPlayer(myId, name));
    _server.listen(_onRequest);
  }

  static Future<HostLobby> start(String name, {int port = lobbyPort}) async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      throw const LobbyException('Lobby konnte nicht gestartet werden.');
    }
    return HostLobby._(server, await localAddresses(), name.trim());
  }

  final HttpServer _server;

  /// Adressen, unter denen die anderen dieses Handy erreichen.
  final List<String> addresses;

  int get port => _server.port;

  String get joinCode => encodeJoinCode(addresses, port);

  final _players = <LobbyPlayer>[];
  final _sockets = <String, WebSocket>{};
  int _nextId = 1;
  String? _gameName;
  OnlineSession? _session;
  String? _closedReason;

  @override
  String get myId => hostId;

  @override
  bool get isHost => true;

  @override
  List<LobbyPlayer> get players => List.unmodifiable(_players);

  @override
  String? get gameName => _gameName;

  @override
  Map<String, dynamic> get view => _session?.viewFor(myId) ?? const {};

  @override
  String? get closedReason => _closedReason;

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = const Duration(seconds: 5);
    String? id;

    socket.listen(
      (raw) {
        final Map<String, dynamic> msg;
        try {
          msg = jsonDecode(raw as String) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        switch (msg['type']) {
          case 'join' when id == null:
            if (_gameName != null) {
              _send(socket, {
                'type': 'error',
                'message': 'Es läuft gerade ein Spiel. Warte, bis es vorbei ist.',
              });
              socket.close();
              return;
            }
            final newId = 'p${_nextId++}';
            id = newId;
            _players.add(LobbyPlayer(newId, _uniqueName('${msg['name']}')));
            _sockets[newId] = socket;
            _send(socket, {'type': 'welcome', 'id': newId});
            _broadcast();
          case 'action' when id != null:
            final data = msg['data'];
            if (data is Map) {
              _session?.onAction(id!, Map<String, dynamic>.from(data));
            }
        }
      },
      onDone: () {
        if (id != null) _removePlayer(id!);
      },
      onError: (_) {},
    );
  }

  String _uniqueName(String wanted) {
    final base = wanted.trim().isEmpty ? 'Spieler' : wanted.trim();
    bool taken(String n) =>
        _players.any((p) => p.name.toLowerCase() == n.toLowerCase());
    var name = base;
    for (var i = 2; taken(name); i++) {
      name = '$base $i';
    }
    return name;
  }

  void _removePlayer(String id) {
    _sockets.remove(id);
    _players.removeWhere((p) => p.id == id);
    _broadcast();
  }

  void startGame(Game game) {
    final online = game.online;
    if (online == null) return;
    _gameName = game.name;
    _session = online.createSession()..start(_players, _broadcast);
    _broadcast();
  }

  void endGame() {
    _gameName = null;
    _session = null;
    _broadcast();
  }

  @override
  void sendAction(Map<String, dynamic> action) =>
      _session?.onAction(myId, action);

  void _broadcast() {
    final players = [for (final p in _players) p.toJson()];
    _sockets.forEach((id, socket) {
      _send(socket, {
        'type': 'state',
        'players': players,
        'game': _gameName,
        'view': _session?.viewFor(id) ?? const {},
      });
    });
    notifyListeners();
  }

  void _send(WebSocket socket, Map<String, dynamic> msg) {
    if (socket.readyState == WebSocket.open) socket.add(jsonEncode(msg));
  }

  @override
  Future<void> leave() async {
    _closedReason = 'Lobby geschlossen.';
    for (final socket in _sockets.values.toList()) {
      await socket.close();
    }
    _sockets.clear();
    await _server.close(force: true);
  }
}

/// Verbindung zur Lobby eines anderen Handys.
class ClientLobby extends Lobby {
  ClientLobby._(this._socket) {
    _socket.listen(
      _onMessage,
      onDone: () {
        if (!_welcome.isCompleted) {
          _welcome.completeError(
              const LobbyException('Verbindung zum Host abgebrochen.'));
        }
        _closedReason ??= 'Verbindung zum Host verloren.';
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  /// Probiert alle Adressen des Hosts durch, bis eine klappt.
  static Future<ClientLobby> join(
    List<String> hosts,
    int port,
    String name,
  ) async {
    LobbyException? error;
    for (final host in hosts) {
      final WebSocket socket;
      try {
        socket = await WebSocket.connect('ws://$host:$port')
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        continue;
      }
      socket.pingInterval = const Duration(seconds: 5);
      final lobby = ClientLobby._(socket);
      socket.add(jsonEncode({'type': 'join', 'name': name.trim()}));
      try {
        await lobby._welcome.future.timeout(const Duration(seconds: 5));
        return lobby;
      } on LobbyException catch (e) {
        error = e;
        await socket.close();
      } on TimeoutException {
        await socket.close();
      }
    }
    throw error ??
        const LobbyException(
            'Lobby nicht gefunden. Seid ihr im selben WLAN oder Hotspot?');
  }

  final WebSocket _socket;
  final _welcome = Completer<void>();
  String _myId = '';
  List<LobbyPlayer> _players = const [];
  String? _gameName;
  Map<String, dynamic> _view = const {};
  String? _closedReason;

  @override
  String get myId => _myId;

  @override
  bool get isHost => false;

  @override
  List<LobbyPlayer> get players => _players;

  @override
  String? get gameName => _gameName;

  @override
  Map<String, dynamic> get view => _view;

  @override
  String? get closedReason => _closedReason;

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'welcome':
        _myId = msg['id'] as String;
        if (!_welcome.isCompleted) _welcome.complete();
      case 'state':
        _players = [
          for (final p in msg['players'] as List)
            LobbyPlayer.fromJson(Map<String, dynamic>.from(p as Map)),
        ];
        _gameName = msg['game'] as String?;
        _view = Map<String, dynamic>.from(msg['view'] as Map);
        notifyListeners();
      case 'error':
        final error = LobbyException('${msg['message']}');
        if (!_welcome.isCompleted) {
          _welcome.completeError(error);
        } else {
          _closedReason = error.message;
          notifyListeners();
        }
    }
  }

  @override
  void sendAction(Map<String, dynamic> action) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(jsonEncode({'type': 'action', 'data': action}));
    }
  }

  @override
  Future<void> leave() async {
    _closedReason = 'Lobby verlassen.';
    await _socket.close();
  }
}
