# Gruppenspiele

Gruppenspiele fürs Handy (Flutter, Android).

<img src="docs/screenshot.png" width="300" alt="Startbildschirm">

## APK aufs Handy holen

Bei jedem Push baut GitHub automatisch eine APK:

1. Im Repo auf **Actions** → **APK bauen** → den neuesten Lauf öffnen.
2. Unten bei **Artifacts** `gruppenspiele-apk` herunterladen (ZIP entpacken).
3. `app-release.apk` öffnen und installieren (Installation aus unbekannten Quellen erlauben).

## Lobby (jeder auf seinem Handy)

Kein Server nötig: Das Handy, das die Lobby erstellt, ist selbst der Server.

1. Einer tippt oben rechts auf **Lobby** → **Lobby erstellen**. Es erscheint ein QR-Code.
2. Die anderen tippen auf **Lobby** → **Beitreten** und scannen den QR-Code
   (oder tippen die angezeigte IP ein).
3. Der Host wählt ein Spiel, alle Handys wechseln ins Spiel.

Alle müssen im **selben WLAN** sein. Ohne WLAN macht der Host einen **Hotspot** an
und die anderen verbinden sich damit (verbraucht keine mobilen Daten).

## Aufbau

```
lib/
  main.dart                 App-Start und Theme
  state/players.dart        Spielerliste (wird auf dem Handy gespeichert)
  state/recent_games.dart   Zuletzt gespielte Spiele
  screens/home_screen.dart  Startseite: großes Spiel oben, Spiele-Reihen
  screens/players_sheet.dart  Spielerverwaltung (schwebender Button)
  screens/lobby_screens.dart  Lobby erstellen/beitreten, Lobby-Raum
  lobby/lobby.dart          Netzwerk: HostLobby (WebSocket-Server) und ClientLobby
  widgets/game_art.dart     Spielgrafik aus Farbe + Icon, großer Titel
  games/
    game.dart               Beschreibung eines Spiels
    registry.dart           Liste aller Spiele
    online.dart             Schnittstelle für den Lobby-Modus
    wer_faengt_an/          Beispiel: ein Handy + Lobby
    impostor/               Beispiel: nur Lobby, geheime Rolle pro Handy
```

## Neues Spiel hinzufügen

1. Ordner `lib/games/<spielname>/` anlegen, z. B. als Kopie von `wer_faengt_an/`.
2. Darin ein `Game(...)` definieren (Name, Beschreibung, Icon, Farbe,
   Mindestspielerzahl, optional `isNew: true`) und den Spiel-Screen bauen. Der Screen bekommt die
   Spielerliste übergeben.
3. Das Spiel in `lib/games/registry.dart` in `allGames` eintragen.

### Lobby-Modus für ein Spiel

Ein Spiel kann `builder` (ein Handy), `online` (Lobby) oder beides haben.
Für `online` braucht es zwei Teile (siehe `impostor/impostor.dart`):

- eine `OnlineSession`: die Spiellogik, läuft nur beim Host. `viewFor(id)` sagt,
  was das Handy jedes Spielers anzeigt, `onAction` reagiert auf Eingaben,
  `update()` schickt allen die neue Ansicht.
- einen `builder`, der aus dieser Ansicht den Bildschirm baut und mit
  `view.send({...})` Aktionen an den Host schickt.
