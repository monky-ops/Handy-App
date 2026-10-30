# Gruppenspiele

Gruppenspiele fürs Handy (Flutter, Android).

<img src="docs/screenshot.png" width="300" alt="Startbildschirm">

## APK aufs Handy holen

Bei jedem Push baut GitHub automatisch eine APK:

1. Im Repo auf **Actions** → **APK bauen** → den neuesten Lauf öffnen.
2. Unten bei **Artifacts** `gruppenspiele-apk` herunterladen (ZIP entpacken).
3. `app-release.apk` öffnen und installieren (Installation aus unbekannten Quellen erlauben).

## Aufbau

```
lib/
  main.dart                 App-Start und Theme
  state/players.dart        Spielerliste (wird auf dem Handy gespeichert)
  screens/home_screen.dart  Startbildschirm: Spieler + Spieleauswahl
  games/
    game.dart               Beschreibung eines Spiels
    registry.dart           Liste aller Spiele
    wer_faengt_an/          Beispielspiel / Vorlage
```

## Neues Spiel hinzufügen

1. Ordner `lib/games/<spielname>/` anlegen, z. B. als Kopie von `wer_faengt_an/`.
2. Darin ein `Game(...)` definieren (Name, Beschreibung, Icon, Farbe,
   Mindestspielerzahl) und den Spiel-Screen bauen. Der Screen bekommt die
   Spielerliste übergeben.
3. Das Spiel in `lib/games/registry.dart` in `allGames` eintragen.
