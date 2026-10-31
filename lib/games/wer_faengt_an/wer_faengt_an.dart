import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/game_art.dart';
import '../game.dart';

/// Beispielspiel und Vorlage für neue Spiele:
/// Lost zufällig aus, wer anfangen muss.
const werFaengtAn = Game(
  name: 'Wer fängt an?',
  description: 'Lost zufällig einen Spieler aus.',
  icon: Icons.casino,
  color: Colors.orange,
  minPlayers: 2,
  isNew: true,
  builder: _build,
);

Widget _build(BuildContext context, List<String> players) =>
    WerFaengtAnScreen(players: players);

class WerFaengtAnScreen extends StatefulWidget {
  const WerFaengtAnScreen({super.key, required this.players});

  final List<String> players;

  @override
  State<WerFaengtAnScreen> createState() => _WerFaengtAnScreenState();
}

class _WerFaengtAnScreenState extends State<WerFaengtAnScreen> {
  final _random = Random();
  String? _current;
  bool _rolling = false;

  Future<void> _roll() async {
    if (_rolling) return;
    setState(() => _rolling = true);
    // Kurz durch die Namen "rattern", dann stehen bleiben.
    for (var i = 0; i < 15; i++) {
      await Future.delayed(Duration(milliseconds: 40 + i * 12));
      if (!mounted) return;
      setState(() {
        _current = widget.players[_random.nextInt(widget.players.length)];
      });
    }
    setState(() => _rolling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Stack(
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
                        child: _current == null
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
                                child: OutlinedTitle(_current!, fontSize: 72),
                              ),
                      ),
                    ),
                  ),
                  if (_current != null && !_rolling)
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
                      onPressed: _rolling ? null : _roll,
                      icon: const Icon(Icons.casino, size: 28),
                      label: Text(_current == null ? 'Auslosen' : 'Nochmal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8FD6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
