import 'dart:io';

/// Wie die Handys einer Lobby miteinander reden. Die Lobby-Logik
/// ([HostLobby], [ClientLobby]) ist davon unabhängig.
///
/// Zwei Varianten:
/// - Internet ([InternetHostTransport]): über einen öffentlichen
///   Vermittler, jeder kann in einem anderen Netz sein.
/// - WLAN/Hotspot ([LocalHostTransport]): direkt im selben Netz,
///   ohne Internet.
abstract class HostTransport {
  /// Ein Mitspieler (Verbindung [conn]) hat eine Nachricht geschickt.
  void Function(String conn, Map<String, dynamic> msg)? onMessage;

  /// Die Verbindung zu einem Mitspieler ist weg.
  void Function(String conn)? onDisconnect;

  /// Der Host selbst hat die Verbindung verloren (z. B. kein Internet mehr).
  void Function()? onLost;

  /// Was in den QR-Code kommt.
  String get joinCode;

  /// Was der Host zum Abtippen anzeigt (Code oder IP).
  String? get displayCode;

  void send(String conn, Map<String, dynamic> msg);

  /// Verbindung zu einem Mitspieler beenden.
  void drop(String conn);

  Future<void> close();
}

abstract class ClientTransport {
  void Function(Map<String, dynamic> msg)? onMessage;

  /// Die Verbindung zum Host ist weg.
  void Function()? onDone;

  void send(Map<String, dynamic> msg);

  Future<void> close();
}

class LobbyException implements Exception {
  const LobbyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Port für Lobbys im WLAN/Hotspot.
const lobbyPort = 4040;

const qrPrefix = 'gruppenspiele:';
const _internetPrefix = '${qrPrefix}net:';

/// Zeichen für Lobby-Codes (ohne leicht verwechselbare wie 0/O, 1/I).
const codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const codeLength = 4;

/// Wohin ein Mitspieler sich verbinden will.
sealed class JoinTarget {
  const JoinTarget();
}

class InternetTarget extends JoinTarget {
  const InternetTarget(this.code);

  final String code;
}

class LocalTarget extends JoinTarget {
  const LocalTarget(this.hosts, this.port);

  final List<String> hosts;
  final int port;
}

String encodeInternetCode(String code) => '$_internetPrefix$code';

String encodeLocalCode(List<String> addresses, int port) =>
    '$qrPrefix${addresses.join(',')}:$port';

/// Liest einen QR-Code, einen eingetippten Lobby-Code oder eine IP.
/// Gibt null zurück, wenn nichts davon passt.
JoinTarget? parseJoinCode(String input) {
  var text = input.trim();
  if (text.startsWith(_internetPrefix)) {
    text = text.substring(_internetPrefix.length);
  }
  final code = text.toUpperCase();
  if (code.length == codeLength &&
      code.split('').every(codeAlphabet.contains)) {
    return InternetTarget(code);
  }

  if (text.startsWith(qrPrefix)) text = text.substring(qrPrefix.length);
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
  return LocalTarget(hosts, port);
}
