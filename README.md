# Gruppenspiele

Gruppenspiele fürs Handy (Flutter, Android).

<img src="docs/screenshot.png" width="300" alt="Startbildschirm">

## APK aufs Handy holen

Bei jedem Push baut GitHub automatisch eine APK:

1. Im Repo auf **Actions** → **APK bauen** → den neuesten Lauf öffnen.
2. Unten bei **Artifacts** `gruppenspiele-apk` herunterladen (ZIP entpacken).
3. `app-release.apk` öffnen und installieren (Installation aus unbekannten Quellen erlauben).

## Lobby (jeder auf seinem Handy)

Kein eigener Server nötig.

1. Einer tippt oben rechts auf **Lobby** → **Lobby erstellen**.
   Es erscheinen ein QR-Code und ein Code wie `KX7P`.
2. Die anderen tippen auf **Lobby** → **Beitreten** und scannen den QR-Code
   oder tippen den Code ein.
3. Der Host wählt ein Spiel, alle Handys wechseln ins Spiel.

**Übers Internet (Standard):** Jeder braucht Internet, egal ob WLAN oder mobile
Daten – man muss nicht im selben Netz sein. Die Handys tauschen ihre Nachrichten
über einen kostenlosen öffentlichen MQTT-Vermittler aus (`broker.hivemq.com`,
siehe `lib/lobby/internet_transport.dart`). Die Spiellogik läuft trotzdem auf
dem Handy des Hosts.

**Ohne Internet:** „Lobby ohne Internet (WLAN/Hotspot)“. Dann müssen alle im
selben WLAN oder im Hotspot des Hosts sein; das Host-Handy ist selbst der Server.

## Aufbau

```
lib/
  main.dart                 App-Start und Theme
  state/players.dart        Spielerliste (wird auf dem Handy gespeichert)
  state/recent_games.dart   Zuletzt gespielte Spiele
  screens/home_screen.dart  Startseite: großes Spiel oben, Spiele-Reihen
  screens/players_sheet.dart  Spielerverwaltung (schwebender Button)
  screens/lobby_screens.dart  Lobby erstellen/beitreten, Lobby-Raum
  lobby/lobby.dart          Lobby-Logik: HostLobby und ClientLobby
  lobby/transport.dart      Schnittstelle für die Verbindung + Codes
  lobby/internet_transport.dart  Verbindung übers Internet (MQTT)
  lobby/local_transport.dart     Verbindung im WLAN/Hotspot (WebSocket)
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

## Tests

```
flutter test
```

Der Internet-Test braucht einen MQTT-Vermittler und läuft nur, wenn
`MQTT_TEST_PORT` gesetzt ist, z. B. mit einem lokalen `amqtt`.
