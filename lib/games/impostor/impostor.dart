import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/game_art.dart';
import '../game.dart';

/// Alle bekommen dasselbe geheime Wort – nur der Impostor nicht.
/// Reihum beschreibt jeder das Wort mit einem Begriff, danach wird
/// abgestimmt, wer der Impostor ist. Nur in der Lobby spielbar.
const impostor = Game(
  name: 'Impostor',
  description: 'Einer kennt das geheime Wort nicht. Findet ihn!',
  icon: Icons.person_search,
  color: Colors.redAccent,
  minPlayers: 3,
  isNew: true,
  online: OnlineGame(createSession: _Session.new, builder: _build),
);

const _words = [
  'Pizza', 'Strand', 'Flughafen', 'Zahnarzt', 'Kino', 'Fußball',
  'Weihnachten', 'Schule', 'Krankenhaus', 'Zoo', 'Supermarkt', 'Hochzeit',
  'Bibliothek', 'Zirkus', 'Feuerwehr', 'Skifahren', 'Camping', 'Bäckerei',
  'Freibad', 'Konzert', 'Bahnhof', 'Gefängnis', 'Fitnessstudio', 'Piraten',
  'Weltall', 'Dschungel', 'Bauernhof', 'Museum', 'Friseur', 'Polizei',
  'Geburtstag', 'Achterbahn', 'Kreuzfahrt', 'Burger', 'Sushi', 'Vampir',
  'Zauberer', 'Ritterburg', 'Tankstelle', 'Spielplatz', 'Hotel', 'U-Bahn',
  'Minecraft', 'Handy', 'Döner', 'Kühlschrank', 'Regenschirm', 'Tattoo',
];

final _random = Random();

class _Session extends OnlineSession {
  int _round = 0;
  late String _word;
  late String _impostorId;
  late String _starterId;
  bool _revealed = false;

  @override
  void onStart() => _newRound();

  void _newRound() {
    _round++;
    _word = _words[_random.nextInt(_words.length)];
    _impostorId = players[_random.nextInt(players.length)].id;
    _starterId = players[_random.nextInt(players.length)].id;
    _revealed = false;
  }

  @override
  void onAction(String playerId, Map<String, dynamic> action) {
    // Nur der Host steuert den Ablauf.
    if (playerId != hostId) return;
    switch (action['type']) {
      case 'reveal':
        _revealed = true;
      case 'next':
        _newRound();
      default:
        return;
    }
    update();
  }

  @override
  Map<String, dynamic> viewFor(String playerId) => {
        'round': _round,
        'starter': nameOf(_starterId),
        if (_revealed) ...{
          'revealed': true,
          'impostor': nameOf(_impostorId),
          'word': _word,
        } else ...{
          'revealed': false,
          'isImpostor': playerId == _impostorId,
          if (playerId != _impostorId) 'word': _word,
        },
      };
}

Widget _build(BuildContext context, OnlineView view) => _ImpostorView(
      // Neue Runde → Karte wieder verdecken.
      key: ValueKey(view.data['round']),
      view: view,
    );

class _ImpostorView extends StatefulWidget {
  const _ImpostorView({super.key, required this.view});

  final OnlineView view;

  @override
  State<_ImpostorView> createState() => _ImpostorViewState();
}

class _ImpostorViewState extends State<_ImpostorView> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final data = view.data;
    final revealed = data['revealed'] == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        const GameArt(game: impostor, iconAlignment: Alignment(0, -0.75)),
        const ColoredBox(color: Color(0xAA000000)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Runde ${data['round']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Expanded(
                  child: Center(
                    child: revealed ? _reveal(data) : _card(data),
                  ),
                ),
                if (!revealed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${data['starter']} beginnt mit dem ersten Begriff.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                if (view.isHost)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => view.send(
                          {'type': revealed ? 'next' : 'reveal'}),
                      icon: Icon(revealed ? Icons.refresh : Icons.visibility),
                      label: Text(revealed ? 'Nächste Runde' : 'Auflösen'),
                      style: bigButtonStyle,
                    ),
                  )
                else
                  const Text(
                    'Der Host löst auf und startet die nächste Runde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Verdeckte Karte, damit niemand mitliest. Tippen zum Umdrehen.
  Widget _card(Map<String, dynamic> data) {
    final isImpostor = data['isImpostor'] == true;
    return GestureDetector(
      onTap: () => setState(() => _visible = !_visible),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 260,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _visible
              ? (isImpostor ? Colors.red.shade900 : const Color(0xFF1E2A44))
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withAlpha(60), width: 2),
        ),
        child: !_visible
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Tippen zum Aufdecken',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isImpostor ? 'Du bist der' : 'Das Wort ist',
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: OutlinedTitle(
                      isImpostor ? 'Impostor' : '${data['word']}',
                      fontSize: 56,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nochmal tippen zum Verdecken',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _reveal(Map<String, dynamic> data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Der Impostor war',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: OutlinedTitle('${data['impostor']}', fontSize: 64),
        ),
        const SizedBox(height: 24),
        Text(
          'Das Wort war: ${data['word']}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
