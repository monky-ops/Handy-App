import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/game.dart';
import '../games/registry.dart';
import '../lobby/lobby.dart';
import '../widgets/game_art.dart';

const _nameKey = 'my_name';

/// Startseite der Lobby: Namen eingeben, Lobby erstellen oder beitreten.
class LobbyStartScreen extends StatefulWidget {
  const LobbyStartScreen({super.key});

  @override
  State<LobbyStartScreen> createState() => _LobbyStartScreenState();
}

class _LobbyStartScreenState extends State<LobbyStartScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && _name.text.isEmpty) {
        _name.text = prefs.getString(_nameKey) ?? '';
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<String?> _checkName() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Gib zuerst deinen Namen ein.');
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    return name;
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _create({required bool internet}) async {
    final name = await _checkName();
    if (name == null || _busy) return;
    setState(() => _busy = true);
    try {
      final lobby = internet
          ? await HostLobby.startInternet(name)
          : await HostLobby.startLocal(name);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LobbyRoomScreen(lobby: lobby)),
      );
    } on LobbyException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final name = await _checkName();
    if (name == null || !mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => JoinScreen(name: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.wifi_tethering, size: 72, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Jeder spielt auf seinem eigenen Handy – egal ob mit WLAN '
              'oder mobilen Daten.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Dein Name',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : () => _create(internet: true),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Lobby erstellen'),
              style: bigButtonStyle,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _join,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Beitreten'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _busy ? null : () => _create(internet: false),
              icon: const Icon(Icons.wifi),
              label: const Text('Lobby ohne Internet (WLAN/Hotspot)'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beitreten: QR-Code des Hosts scannen oder seine IP eintippen.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.name});

  final String name;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _connect(String code) async {
    if (_busy) return;
    if (parseJoinCode(code) == null) {
      _snack('Ungültiger Code.');
      return;
    }
    setState(() => _busy = true);
    try {
      final lobby = await ClientLobby.join(code, widget.name);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LobbyRoomScreen(lobby: lobby)),
      );
    } on LobbyException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beitreten')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Scanne den QR-Code auf dem Handy des Hosts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final value = capture.barcodes.firstOrNull?.rawValue;
                        if (value != null) _connect(value);
                      },
                    ),
                    if (_busy)
                      const ColoredBox(
                        color: Color(0xAA000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oder den Code des Hosts eintippen:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    style: const TextStyle(fontSize: 22, letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: 'z. B. KX7P',
                      hintStyle: const TextStyle(letterSpacing: 4),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _connect,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _busy ? null : () => _connect(_code.text),
                  icon: const Icon(Icons.login),
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Lobby: Spielerliste, beim Host QR-Code und Spielauswahl.
/// Läuft ein Spiel, zeigt sie stattdessen das Spiel an.
class LobbyRoomScreen extends StatefulWidget {
  const LobbyRoomScreen({super.key, required this.lobby});

  final Lobby lobby;

  @override
  State<LobbyRoomScreen> createState() => _LobbyRoomScreenState();
}

class _LobbyRoomScreenState extends State<LobbyRoomScreen> {
  Lobby get lobby => widget.lobby;

  @override
  void dispose() {
    lobby.leave();
    lobby.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    if (lobby.closedReason != null) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lobby.isHost ? 'Lobby schließen?' : 'Lobby verlassen?'),
        content: lobby.isHost
            ? const Text('Alle anderen fliegen dann auch raus.')
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lobby.isHost ? 'Schließen' : 'Verlassen'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: ListenableBuilder(
        listenable: lobby,
        builder: (context, _) {
          final closed = lobby.closedReason;
          if (closed != null) return _ClosedView(message: closed);

          final game = lobby.game;
          final online = game?.online;
          if (game != null && online != null) {
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(game.name),
                actions: [
                  if (lobby is HostLobby)
                    TextButton(
                      onPressed: (lobby as HostLobby).endGame,
                      child: const Text('Beenden'),
                    ),
                ],
              ),
              body: online.builder(
                context,
                OnlineView(
                  data: lobby.view,
                  myId: lobby.myId,
                  isHost: lobby.isHost,
                  players: lobby.players,
                  send: lobby.sendAction,
                ),
              ),
            );
          }
          return _LobbyView(lobby: lobby);
        },
      ),
    );
  }
}

class _ClosedView extends StatelessWidget {
  const _ClosedView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.wifi_off, size: 72, color: Colors.white54),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: bigButtonStyle,
                child: const Text('Zurück'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({required this.lobby});

  final Lobby lobby;

  @override
  Widget build(BuildContext context) {
    final host = lobby is HostLobby ? lobby as HostLobby : null;
    final onlineGames = allGames.where((g) => g.online != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(host != null ? 'Deine Lobby' : 'Lobby'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (host != null) _JoinInfo(host: host),
            const SizedBox(height: 24),
            _SectionTitle('Spieler (${lobby.players.length})'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in lobby.players)
                  Chip(
                    avatar: Icon(
                      p.id == hostId ? Icons.star : Icons.person,
                      size: 18,
                    ),
                    label: Text(p.id == lobby.myId ? '${p.name} (du)' : p.name),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            if (host != null) ...[
              const _SectionTitle('Spiel starten'),
              const SizedBox(height: 8),
              for (final game in onlineGames)
                _GameListTile(
                  game: game,
                  onTap: () {
                    if (lobby.players.length < game.minPlayers) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(
                            '${game.name} braucht mindestens '
                            '${game.minPlayers} Spieler.',
                          ),
                        ));
                      return;
                    }
                    host.startGame(game);
                  },
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Warte, bis der Host ein Spiel startet …',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JoinInfo extends StatelessWidget {
  const _JoinInfo({required this.host});

  final HostLobby host;

  @override
  Widget build(BuildContext context) {
    final code = host.displayCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (code == null)
              const Text(
                'Kein WLAN gefunden. Verbinde dich mit einem WLAN oder '
                'mach einen Hotspot an und öffne die Lobby neu.',
                textAlign: TextAlign.center,
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: QrImageView(
                  data: host.joinCode,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                host.isInternet ? 'Lobby-Code' : 'IP zum Beitreten',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SelectableText(
                code,
                style: TextStyle(
                  fontSize: host.isInternet ? 44 : 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: host.isInternet ? 8 : 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                host.isInternet
                    ? 'QR-Code scannen oder Code eintippen. '
                        'Jeder braucht Internet (WLAN oder mobile Daten).'
                    : 'Alle im selben WLAN oder in deinem Hotspot.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _GameListTile extends StatelessWidget {
  const _GameListTile({required this.game, required this.onTap});

  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: GameArt(game: game, iconScale: 0.4),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ab ${game.minPlayers} Spieler',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.play_arrow_rounded, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}
