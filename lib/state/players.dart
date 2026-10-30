import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die Spielerliste der Runde. Wird auf dem Handy gespeichert,
/// damit sie beim nächsten Start noch da ist.
class Players extends ChangeNotifier {
  static const _storageKey = 'players';

  final List<String> _names = [];

  List<String> get names => List.unmodifiable(_names);
  int get count => _names.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _names
      ..clear()
      ..addAll(prefs.getStringList(_storageKey) ?? const []);
    notifyListeners();
  }

  /// Fügt einen Spieler hinzu. Gibt false zurück, wenn der Name leer
  /// oder schon vergeben ist.
  bool add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final exists =
        _names.any((n) => n.toLowerCase() == trimmed.toLowerCase());
    if (exists) return false;
    _names.add(trimmed);
    _changed();
    return true;
  }

  void removeAt(int index) {
    _names.removeAt(index);
    _changed();
  }

  void clear() {
    _names.clear();
    _changed();
  }

  void _changed() {
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setStringList(_storageKey, _names));
  }
}

/// Macht die Spielerliste überall in der App verfügbar:
/// `PlayersScope.of(context)`.
class PlayersScope extends InheritedNotifier<Players> {
  const PlayersScope({
    super.key,
    required Players players,
    required super.child,
  }) : super(notifier: players);

  static Players of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayersScope>()!.notifier!;
}
