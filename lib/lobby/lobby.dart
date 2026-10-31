import 'dart:async';

import 'package:flutter/foundation.dart';

import '../games/game.dart';
import '../games/registry.dart';
import 'internet_transport.dart';
import 'local_transport.dart';
import 'transport.dart';

export 'transport.dart';

/// Eine Lobby aus Sicht dieses Handys – egal ob Host oder Mitspieler.
///
/// Nachrichten (JSON, über Internet oder WLAN – siehe transport.dart):
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

/// Lobby auf dem eigenen Handy: verwaltet die Spieler und lässt die
/// Spiellogik laufen.
class HostLobby extends Lobby {
  HostLobby(this._transport, String name) {
    _players.add(LobbyPlayer(myId, name.trim()));
    _transport
      ..onMessage = _onMessage
      ..onDisconnect = _onDisconnect
      ..onLost = () {
        _closedReason = 'Verbindung verloren. Hast du noch Internet?';
        notifyListeners();
      };
  }

  /// Lobby übers Internet: jeder kann in einem anderen Netz sein.
  static Future<HostLobby> startInternet(String name) async =>
      HostLobby(await InternetHostTransport.start(), name);

  /// Lobby im WLAN/Hotspot: ohne Internet, alle im selben Netz.
  static Future<HostLobby> startLocal(String name) async =>
      HostLobby(await LocalHostTransport.start(), name);

  final HostTransport _transport;

  bool get isInternet => _transport is InternetHostTransport;

  /// Inhalt des QR-Codes.
  String get joinCode => _transport.joinCode;

  /// Code oder IP zum Abtippen (null: kein Netz gefunden).
  String? get displayCode => _transport.displayCode;

  final _players = <LobbyPlayer>[];

  /// Verbindung → Spieler-ID.
  final _connToPlayer = <String, String>{};
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

  void _onMessage(String conn, Map<String, dynamic> msg) {
    final id = _connToPlayer[conn];
    switch (msg['type']) {
      case 'join' when id == null:
        if (_gameName != null) {
          _transport
            ..send(conn, {
              'type': 'error',
              'message': 'Es läuft gerade ein Spiel. Warte, bis es vorbei ist.',
            })
            ..drop(conn);
          return;
        }
        final newId = 'p${_nextId++}';
        _connToPlayer[conn] = newId;
        _players.add(LobbyPlayer(newId, _uniqueName('${msg['name']}')));
        _transport.send(conn, {'type': 'welcome', 'id': newId});
        _broadcast();
      case 'action' when id != null:
        final data = msg['data'];
        if (data is Map) {
          _session?.onAction(id, Map<String, dynamic>.from(data));
        }
    }
  }

  void _onDisconnect(String conn) {
    final id = _connToPlayer.remove(conn);
    if (id == null) return;
    _players.removeWhere((p) => p.id == id);
    _broadcast();
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
    _connToPlayer.forEach((conn, id) {
      _transport.send(conn, {
        'type': 'state',
        'players': players,
        'game': _gameName,
        'view': _session?.viewFor(id) ?? const {},
      });
    });
    notifyListeners();
  }

  @override
  Future<void> leave() async {
    _closedReason ??= 'Lobby geschlossen.';
    await _transport.close();
  }
}

/// Verbindung zur Lobby eines anderen Handys.
class ClientLobby extends Lobby {
  ClientLobby(this._transport) {
    _transport
      ..onMessage = _onMessage
      ..onDone = () {
        if (!_welcome.isCompleted) {
          _welcome.completeError(
              const LobbyException('Verbindung zum Host abgebrochen.'));
        }
        _closedReason ??= 'Der Host hat die Lobby verlassen.';
        notifyListeners();
      };
  }

  /// Tritt einer Lobby bei. [code] ist ein Lobby-Code, QR-Inhalt oder IP.
  static Future<ClientLobby> join(String code, String name) async {
    final target = parseJoinCode(code);
    if (target == null) throw const LobbyException('Ungültiger Code.');
    return joinTarget(target, name);
  }

  static Future<ClientLobby> joinTarget(
    JoinTarget target,
    String name, {
    Future<ClientTransport?> Function(JoinTarget target)? connect,
  }) async {
    final transport = await (connect ?? _connect)(target);
    if (transport == null) {
      throw const LobbyException(
          'Lobby nicht gefunden. Seid ihr im selben WLAN oder Hotspot?');
    }
    final lobby = ClientLobby(transport);
    transport.send({'type': 'join', 'name': name.trim()});
    try {
      await lobby._welcome.future.timeout(const Duration(seconds: 8));
      return lobby;
    } on TimeoutException {
      await transport.close();
      throw LobbyException(target is InternetTarget
          ? 'Keine Lobby mit dem Code ${target.code} gefunden.'
          : 'Der Host antwortet nicht.');
    } on LobbyException {
      await transport.close();
      rethrow;
    }
  }

  static Future<ClientTransport?> _connect(JoinTarget target) =>
      switch (target) {
        InternetTarget() => InternetClientTransport.connect(target),
        LocalTarget() => LocalClientTransport.connect(target),
      };

  final ClientTransport _transport;
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

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'welcome' when !_welcome.isCompleted:
        _myId = msg['id'] as String;
        _welcome.complete();
      case 'state' when _welcome.isCompleted:
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
  void sendAction(Map<String, dynamic> action) =>
      _transport.send({'type': 'action', 'data': action});

  @override
  Future<void> leave() async {
    _closedReason ??= 'Lobby verlassen.';
    await _transport.close();
  }
}
