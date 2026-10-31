import 'dart:math';

import 'package:flutter/material.dart';

import '../games/game.dart';

/// Hintergrundbild für ein Spiel: Farbverlauf in der Spielfarbe
/// mit verstreuten, gedrehten Spiel-Icons.
class GameArt extends StatelessWidget {
  const GameArt({
    super.key,
    required this.game,
    this.iconScale = 1,
    this.iconAlignment = Alignment.center,
  });

  final Game game;
  final double iconScale;

  /// Wo das große Icon sitzt (z. B. oben, damit Text darunter Platz hat).
  final Alignment iconAlignment;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(game.color);
    final light = hsl.withLightness(0.6).toColor();
    final dark = hsl.withLightness(0.18).toColor();

    return LayoutBuilder(
      builder: (context, size) {
        // Fester Seed pro Spiel, damit das Muster immer gleich aussieht.
        final random = Random(game.name.hashCode);
        final icons = <Widget>[];
        for (var i = 0; i < 9; i++) {
          final s = (40 + random.nextDouble() * 70) * iconScale;
          icons.add(Positioned(
            left: random.nextDouble() * size.maxWidth - s / 2,
            top: random.nextDouble() * size.maxHeight - s / 2,
            child: Transform.rotate(
              angle: (random.nextDouble() - 0.5) * 1.2,
              child: Icon(
                game.icon,
                size: s,
                color: Colors.white.withAlpha(25 + random.nextInt(30)),
              ),
            ),
          ));
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, game.color, dark],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ...icons,
              Align(
                alignment: iconAlignment,
                child: Icon(
                  game.icon,
                  size: min(size.maxWidth, size.maxHeight) * 0.42,
                  color: Colors.white,
                  shadows: const [
                    Shadow(blurRadius: 24, color: Colors.black54),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Großer blauer Button im Stil der App (z. B. „Spielen“).
final bigButtonStyle = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF6B8FD6),
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 18),
  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
);

/// Großer, fetter Titel mit schwarzer Umrandung.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(this.text, {super.key, this.fontSize = 64});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      height: 0.95,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
    );
    final upper = text.toUpperCase();
    return Stack(
      children: [
        Text(
          upper,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize / 8
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
          ),
        ),
        Text(
          upper,
          textAlign: TextAlign.center,
          style: style.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
