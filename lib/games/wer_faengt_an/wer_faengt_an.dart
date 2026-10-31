import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/game_art.dart';
import '../game.dart';

/// Beispielspiel und Vorlage für neue Spiele:
/// Lost zufällig aus, wer anfangen muss. Geht mit einem Handy
/// und in der Lobby (alle sehen das Ergebnis gleichzeitig).
const werFaengtAn = Game(
  name: 'Wer fängt an?',
  description: 'Lost zufällig einen Spieler aus.',
  icon: Icons.casino,
  color: Colors.orange,
  minPlayers: 2,
  builder: _buildLocal,
  online: OnlineGame(createSession: _Session.new, builder: _buildOnline),
);

final _random = Random();

// ---------- Ein Handy ----------

Widget _buildLocal(BuildContext context, List<String> players) =>
    _LocalScreen(players: players);

class _LocalScreen extends StatefulWidget {
  const _LocalScreen({required this.players});

  final List<String> players;

  @override
  State<_LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<_LocalScreen> {
  String? _result;
  int _roll = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: _RollView(
        players: widget.players,
        result: _result,
        roll: _roll,
        onRoll: () => setState(() {
          _result = widget.players[_random.nextInt(widget.players.length)];
          _roll++;
        }),
      ),
    );
  }
}

// ---------- Lobby ----------

class _Session extends OnlineSession {
  String? _result;
  int _roll = 0;

  @override
  void onAction(String playerId, Map<String, dynamic> action) {
    if (action['type'] == 'roll') {
      _result = players[_random.nextInt(players.length)].name;
      _roll++;
      update();
    }
  }

  @override
  Map<String, dynamic> viewFor(String playerId) =>
      {'result': _result, 'roll': _roll};
}

Widget _buildOnline(BuildContext context, OnlineView view) => _RollView(
      players: [for (final p in view.players) p.name],
      result: view.data['result'] as String?,
      roll: view.data['roll'] as int? ?? 0,
      onRoll: () => view.send({'type': 'roll'}),
    );

// ---------- Anzeige (für beide Modi) ----------

/// Zeigt das Ergebnis. Ändert sich [roll], rattern erst kurz die Namen
/// durch, bevor [result] stehen bleibt.
class _RollView extends StatefulWidget {
  const _RollView({
    required this.players,
    required this.result,
    required this.roll,
    required this.onRoll,
  });

  final List<String> players;
  final String? result;
  final int roll;
  final VoidCallback onRoll;

  @override
  State<_RollView> createState() => _RollViewState();
}

class _RollViewState extends State<_RollView> {
  String? _shown;
  bool _rolling = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.result;
  }

  @override
  void didUpdateWidget(_RollView old) {
    super.didUpdateWidget(old);
    if (widget.roll != old.roll) _animate();
  }

  Future<void> _animate() async {
    setState(() => _rolling = true);
    for (var i = 0; i < 15; i++) {
      await Future.delayed(Duration(milliseconds: 40 + i * 12));
      if (!mounted) return;
      setState(() {
        _shown = widget.players[_random.nextInt(widget.players.length)];
      });
    }
    if (!mounted) return;
    setState(() {
      _shown = widget.result;
      _rolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GameArt(game: werFaengtAn, iconAlignment: Alignment(0, -0.6)),
        const ColoredBox(color: Color(0x88000000)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _rolling ? 0.6 : 1,
                      child: _shown == null
                          ? const Text(
                              'Tippe auf Auslosen',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 22,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: OutlinedTitle(_shown!, fontSize: 72),
                            ),
                    ),
                  ),
                ),
                if (_shown != null && !_rolling)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'fängt an!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _rolling ? null : widget.onRoll,
                    icon: const Icon(Icons.casino, size: 28),
                    label: Text(_shown == null ? 'Auslosen' : 'Nochmal'),
                    style: bigButtonStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
