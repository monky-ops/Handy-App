import 'package:flutter/material.dart';

import '../state/players.dart';

/// Öffnet die Spielerverwaltung von unten.
Future<void> showPlayersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF16161C),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: const _PlayersSheet(),
    ),
  );
}

class _PlayersSheet extends StatefulWidget {
  const _PlayersSheet();

  @override
  State<_PlayersSheet> createState() => _PlayersSheetState();
}

class _PlayersSheetState extends State<_PlayersSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(Players players) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (players.add(name)) {
        _controller.clear();
        _error = null;
      } else {
        _error = '„$name“ ist schon dabei.';
      }
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final players = PlayersScope.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Spieler (${players.count})',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (players.count > 0)
                  TextButton(
                    onPressed: () => _confirmClear(players),
                    child: const Text('Alle löschen'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: players.count == 0,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Name eingeben',
                      errorText: _error,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _add(players),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: () => _add(players),
                  icon: const Icon(Icons.person_add),
                  iconSize: 28,
                  tooltip: 'Hinzufügen',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (players.count == 0)
              Text(
                'Füge alle hinzu, die mitspielen.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < players.count; i++)
                        InputChip(
                          label: Text(players.names[i]),
                          onDeleted: () => players.removeAt(i),
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                ),
              ),
          ],
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
