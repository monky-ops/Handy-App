import 'package:flutter/material.dart';

import 'online.dart';

export 'online.dart';

/// Beschreibt ein Spiel für die Spieleauswahl.
///
/// Ein Spiel kann zwei Modi haben (mindestens einen):
/// - [builder]: ein Handy, das herumgereicht wird.
/// - [online]: jeder spielt in der Lobby auf seinem eigenen Handy.
///
/// Neues Spiel hinzufügen:
/// 1. Ordner unter `lib/games/<spielname>/` anlegen.
/// 2. Darin eine Datei mit einem `Game(...)` und dem Spiel-Screen.
/// 3. Das Spiel in `lib/games/registry.dart` in die Liste eintragen.
class Game {
  const Game({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.builder,
    this.online,
    this.minPlayers = 1,
    this.isNew = false,
  }) : assert(builder != null || online != null);

  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// Wie viele Spieler mindestens dabei sein müssen.
  final int minPlayers;

  /// Zeigt das Abzeichen „NEU“ auf der Startseite.
  final bool isNew;

  /// Ein-Handy-Modus: baut den Spiel-Screen. Bekommt die Spielerliste.
  final Widget Function(BuildContext context, List<String> players)? builder;

  /// Lobby-Modus: jeder Spieler auf seinem eigenen Handy.
  final OnlineGame? online;
}
