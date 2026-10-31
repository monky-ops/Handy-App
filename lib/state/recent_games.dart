import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Merkt sich, welche Spiele zuletzt gespielt wurden (neueste zuerst).
class RecentGames extends ChangeNotifier {
  static const _storageKey = 'recent_games';
  static const _max = 10;

  final List<String> _names = [];

  List<String> get names => List.unmodifiable(_names);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _names
      ..clear()
      ..addAll(prefs.getStringList(_storageKey) ?? const []);
    notifyListeners();
  }

  void played(String gameName) {
    _names
      ..remove(gameName)
      ..insert(0, gameName);
    if (_names.length > _max) _names.removeRange(_max, _names.length);
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setStringList(_storageKey, _names));
  }
}

/// `RecentGamesScope.of(context)` liefert die zuletzt gespielten Spiele.
class RecentGamesScope extends InheritedNotifier<RecentGames> {
  const RecentGamesScope({
    super.key,
    required RecentGames recent,
    required super.child,
  }) : super(notifier: recent);

  static RecentGames of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RecentGamesScope>()!
      .notifier!;
}
