import 'package:flutter/material.dart';

/// Beschreibt ein Spiel für die Spieleauswahl.
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
    required this.builder,
    this.minPlayers = 1,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// Wie viele Spieler mindestens eingetragen sein müssen.
  final int minPlayers;

  /// Baut den Spiel-Screen. Bekommt die aktuelle Spielerliste.
  final Widget Function(BuildContext context, List<String> players) builder;
}
