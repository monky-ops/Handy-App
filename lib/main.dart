import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'state/players.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final players = Players();
  await players.load();
  runApp(GruppenspieleApp(players: players));
}

class GruppenspieleApp extends StatelessWidget {
  const GruppenspieleApp({super.key, required this.players});

  final Players players;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.deepPurple;
    return PlayersScope(
      players: players,
      child: MaterialApp(
        title: 'Gruppenspiele',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
