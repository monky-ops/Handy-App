import 'package:flutter/material.dart';

import '../games/game.dart';
import '../games/registry.dart';
import '../state/players.dart';
import '../state/recent_games.dart';
import '../widgets/game_art.dart';
import 'players_sheet.dart';

/// Startet ein Spiel, wenn genug Spieler da sind, und merkt es sich
/// unter „Zuletzt gespielt“.
void openGame(BuildContext context, Game game) {
  final players = PlayersScope.of(context);
  if (players.count < game.minPlayers) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${game.name} braucht mindestens ${game.minPlayers} Spieler.',
          ),
          action: SnackBarAction(
            label: 'Spieler',
            onPressed: () => showPlayersSheet(context),
          ),
        ),
      );
    return;
  }
  RecentGamesScope.of(context).played(game.name);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => game.builder(context, players.names),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recent = RecentGamesScope.of(context)
        .names
        .map((n) => allGames.where((g) => g.name == n).firstOrNull)
        .whereType<Game>()
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _Hero()),
              if (recent.isNotEmpty)
                _GameRow(
                  icon: Icons.history,
                  title: 'Zuletzt gespielt',
                  games: recent,
                ),
              const _GameRow(
                icon: Icons.grid_view_rounded,
                title: 'Alle Spiele',
                games: allGames,
              ),
              // Platz für den schwebenden Spieler-Button.
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          const Positioned(
            right: 16,
            bottom: 24,
            child: SafeArea(child: _PlayersButton()),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.74;
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: allGames.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _HeroPage(game: allGames[i]),
          ),
          Positioned(
            left: 20,
            top: top + 16,
            child: const Text(
              'Gruppenspiele',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
              ),
            ),
          ),
          if (allGames.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: _PageDots(count: allGames.length, current: _page),
            ),
        ],
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        GameArt(
          game: game,
          iconScale: 1.6,
          iconAlignment: const Alignment(0, -0.5),
        ),
        // Nach unten ins Schwarze ausblenden.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.45, 0.75, 1],
              colors: [
                Color(0x33000000),
                Colors.transparent,
                Color(0xCC000000),
                Colors.black,
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Column(
            children: [
              OutlinedTitle(game.name),
              const SizedBox(height: 16),
              if (game.isNew) ...[
                const _Badge('NEU'),
                const SizedBox(height: 12),
              ],
              Text(
                game.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _PlayButton(onPressed: () => openGame(context, game)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(90)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: color.withAlpha(110), blurRadius: 24),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded, size: 30),
        label: const Text('Spielen'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6B8FD6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          side: BorderSide(color: Colors.white.withAlpha(60)),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.icon,
    required this.title,
    required this.games,
  });

  final IconData icon;
  final String title;
  final List<Game> games;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) => _GameCard(game: games[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => openGame(context, game),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameArt(game: game, iconScale: 0.6),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.5, 1],
                      colors: [Colors.transparent, Color(0xDD000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ab ${game.minPlayers} Spieler',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Schwebender Button unten rechts, öffnet die Spielerliste.
class _PlayersButton extends StatelessWidget {
  const _PlayersButton();

  @override
  Widget build(BuildContext context) {
    final count = PlayersScope.of(context).count;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B3FA0), Color(0xFFC0406E)],
        ),
        border: Border.all(color: Colors.white.withAlpha(50)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => showPlayersSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 0 ? 'Spieler hinzufügen' : 'Spieler · $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.groups_rounded, color: Colors.white, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
