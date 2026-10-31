import 'package:flutter/widgets.dart';

/// Ein Spieler in der Lobby.
class LobbyPlayer {
  const LobbyPlayer(this.id, this.name);

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory LobbyPlayer.fromJson(Map<String, dynamic> json) =>
      LobbyPlayer(json['id'] as String, json['name'] as String);
}

/// Lobby-Modus eines Spiels.
///
/// Die Spiellogik ([OnlineSession]) läuft nur auf dem Handy des Hosts.
/// Jedes Handy bekommt daraus seine eigene Ansicht ([OnlineSession.viewFor])
/// und zeigt sie mit [builder] an. Tippt ein Spieler etwas, schickt er eine
/// Aktion an den Host ([OnlineView.send] → [OnlineSession.onAction]).
class OnlineGame {
  const OnlineGame({required this.createSession, required this.builder});

  final OnlineSession Function() createSession;
  final Widget Function(BuildContext context, OnlineView view) builder;
}

/// Spieler-ID des Hosts (das Handy, das die Lobby erstellt hat).
const hostId = 'host';

/// Spiellogik auf dem Host-Handy.
abstract class OnlineSession {
  late List<LobbyPlayer> players;
  late VoidCallback _changed;

  void start(List<LobbyPlayer> players, VoidCallback changed) {
    this.players = List.of(players);
    _changed = changed;
    onStart();
  }

  /// Wird beim Spielstart aufgerufen.
  void onStart() {}

  /// Nach jeder Änderung aufrufen, damit alle Handys die neue Ansicht bekommen.
  void update() => _changed();

  /// Ein Spieler hat etwas getan (z. B. einen Button gedrückt).
  void onAction(String playerId, Map<String, dynamic> action);

  /// Was das Handy dieses Spielers anzeigen soll. Muss JSON-fähig sein.
  Map<String, dynamic> viewFor(String playerId);

  String nameOf(String playerId) =>
      players.where((p) => p.id == playerId).firstOrNull?.name ?? '?';
}

/// Was ein Handy für das laufende Spiel anzeigt.
class OnlineView {
  const OnlineView({
    required this.data,
    required this.myId,
    required this.isHost,
    required this.players,
    required this.send,
  });

  /// Die Ansicht aus [OnlineSession.viewFor].
  final Map<String, dynamic> data;
  final String myId;
  final bool isHost;
  final List<LobbyPlayer> players;

  /// Schickt eine Aktion an den Host.
  final void Function(Map<String, dynamic> action) send;
}
