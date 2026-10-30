import 'dart:math';

import 'package:flutter/material.dart';

import '../game.dart';

/// Beispielspiel und Vorlage für neue Spiele:
/// Lost zufällig aus, wer anfangen muss.
const werFaengtAn = Game(
  name: 'Wer fängt an?',
  description: 'Lost zufällig einen Spieler aus.',
  icon: Icons.casino,
  color: Colors.orange,
  minPlayers: 2,
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wer fängt an?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: theme.textTheme.displayMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _rolling
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    child: Text(_current ?? 'Tippe auf Auslosen'),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _rolling ? null : _roll,
                  icon: const Icon(Icons.casino),
                  label: const Text('Auslosen'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
