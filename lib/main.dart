import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'state/players.dart';
import 'state/recent_games.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final players = Players();
  final recent = RecentGames();
  await Future.wait([players.load(), recent.load()]);
  runApp(GruppenspieleApp(players: players, recent: recent));
}

class GruppenspieleApp extends StatelessWidget {
  const GruppenspieleApp({
    super.key,
    required this.players,
    required this.recent,
  });

  final Players players;
  final RecentGames recent;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B8FD6),
      brightness: Brightness.dark,
    ).copyWith(surface: Colors.black);

    return PlayersScope(
      players: players,
      child: RecentGamesScope(
        recent: recent,
        child: MaterialApp(
          title: 'Gruppenspiele',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: scheme,
            scaffoldBackgroundColor: Colors.black,
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
