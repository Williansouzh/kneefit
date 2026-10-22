import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'screens/body_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/today_screen.dart';
import 'screens/training_screen.dart';
import 'services/alarms.dart';
import 'services/cloud.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final store = Store(await getApplicationDocumentsDirectory());
  await store.load();
  final alarms = Alarms();
  alarms.sync(store.meals).ignore();
  final cloud = Cloud(store);
  await cloud.load();
  cloud.sync().ignore();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      Provider.value(value: alarms),
      ChangeNotifierProvider.value(value: cloud),
    ],
    child: const FitKneeApp(),
  ));
}

class FitKneeApp extends StatelessWidget {
  const FitKneeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FitKnee',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void go(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: [
          TodayScreen(onTab: go),
          const TrainingScreen(),
          const BodyScreen(),
          const DiaryScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Hoje'),
            NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Treino'),
            NavigationDestination(
                icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: 'Corpo'),
            NavigationDestination(icon: Icon(Icons.videocam_outlined), selectedIcon: Icon(Icons.videocam), label: 'Diário'),
          ],
        ),
      );
}
