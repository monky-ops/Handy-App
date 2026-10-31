import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'transport.dart';

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

Map<String, dynamic>? _decode(dynamic raw) {
  try {
    return jsonDecode(raw as String) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// WLAN/Hotspot: Das Host-Handy startet einen WebSocket-Server.
class LocalHostTransport extends HostTransport {
  LocalHostTransport._(this._server, this.addresses) {
    _server.listen(_onRequest);
  }

  static Future<LocalHostTransport> start({int port = lobbyPort}) async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      throw const LobbyException('Lobby konnte nicht gestartet werden.');
    }
    return LocalHostTransport._(server, await localAddresses());
  }

  final HttpServer _server;

  /// Adressen, unter denen die anderen dieses Handy erreichen.
  final List<String> addresses;

  int get port => _server.port;

  final _sockets = <String, WebSocket>{};
  int _next = 1;

  @override
  String get joinCode => encodeLocalCode(addresses, port);

  @override
  String? get displayCode => addresses.firstOrNull;

  Future<void> _onRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = const Duration(seconds: 5);
    final conn = 'c${_next++}';
    _sockets[conn] = socket;
    socket.listen(
      (raw) {
        final msg = _decode(raw);
        if (msg != null) onMessage?.call(conn, msg);
      },
      onDone: () {
        _sockets.remove(conn);
        onDisconnect?.call(conn);
      },
      onError: (_) {},
    );
  }

  @override
  void send(String conn, Map<String, dynamic> msg) {
    final socket = _sockets[conn];
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(msg));
    }
  }

  @override
  void drop(String conn) => _sockets[conn]?.close();

  @override
  Future<void> close() async {
    for (final socket in _sockets.values.toList()) {
      await socket.close();
    }
    _sockets.clear();
    await _server.close(force: true);
  }
}

class LocalClientTransport extends ClientTransport {
  LocalClientTransport._(this._socket) {
    _socket.listen(
      (raw) {
        final msg = _decode(raw);
        if (msg != null) onMessage?.call(msg);
      },
      onDone: () => onDone?.call(),
      onError: (_) {},
    );
  }

  /// Verbindet sich mit der ersten erreichbaren Adresse, sonst null.
  static Future<LocalClientTransport?> connect(LocalTarget target) async {
    for (final host in target.hosts) {
      try {
        final socket = await WebSocket.connect('ws://$host:${target.port}')
            .timeout(const Duration(seconds: 4));
        socket.pingInterval = const Duration(seconds: 5);
        return LocalClientTransport._(socket);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  final WebSocket _socket;

  @override
  void send(Map<String, dynamic> msg) {
    if (_socket.readyState == WebSocket.open) _socket.add(jsonEncode(msg));
  }

  @override
  Future<void> close() => _socket.close();
}
