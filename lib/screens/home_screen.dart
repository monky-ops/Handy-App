import 'package:flutter/material.dart';

import '../games/game.dart';
import '../games/registry.dart';
import '../state/players.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppenspiele'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _PlayersSection()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Spiele',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: allGames.length,
                itemBuilder: (context, i) => _GameTile(game: allGames[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayersSection extends StatefulWidget {
  const _PlayersSection();

  @override
  State<_PlayersSection> createState() => _PlayersSectionState();
}

class _PlayersSectionState extends State<_PlayersSection> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(Players players) {
    final name = _controller.text;
    if (name.trim().isEmpty) return;
    if (players.add(name)) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('„${name.trim()}“ ist schon dabei.')),
        );
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final players = PlayersScope.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Spieler (${players.count})',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (players.count > 0)
                    TextButton(
                      onPressed: () => _confirmClear(players),
                      child: const Text('Alle löschen'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Name eingeben',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _add(players),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _add(players),
                    icon: const Icon(Icons.person_add),
                    tooltip: 'Hinzufügen',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (players.count == 0)
                Text(
                  'Noch keine Spieler. Füge alle hinzu, die mitspielen.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < players.count; i++)
                      InputChip(
                        label: Text(players.names[i]),
                        onDeleted: () => players.removeAt(i),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(Players players) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Spieler löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) players.clear();
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});

  final Game game;

  void _open(BuildContext context) {
    final players = PlayersScope.of(context);
    if (players.count < game.minPlayers) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${game.name} braucht mindestens ${game.minPlayers} Spieler.',
            ),
          ),
        );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => game.builder(context, players.names),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: game.color.withAlpha(51),
                child: Icon(game.icon, color: game.color, size: 30),
              ),
              const Spacer(),
              Text(
                game.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                game.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ab ${game.minPlayers} Spieler',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
