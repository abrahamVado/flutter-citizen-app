import 'package:flutter/material.dart';

import 'folio_lookup_screen.dart';
import 'home/citizen_home_screen.dart';
import 'map/citizen_map_screen.dart';

class PublicShell extends StatefulWidget {
  const PublicShell({super.key});

  @override
  State<PublicShell> createState() => _PublicShellState();
}

class _PublicShellState extends State<PublicShell> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    //1.- Resolvemos la ruta solicitada para mantener un grafo público sencillo.
    switch (settings.name) {
      case '/map':
        return MaterialPageRoute(builder: (_) => const CitizenMapScreen());
      case '/folio':
        return MaterialPageRoute(builder: (_) => const FolioLookupScreen());
      default:
        return MaterialPageRoute(builder: (_) => const CitizenHomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    //1.- Montamos un Navigator dedicado que evita que el stack público se mezcle con el administrativo.
    return Navigator(
      key: _navigatorKey,
      initialRoute: '/',
      onGenerateRoute: _onGenerateRoute,
    );
  }
}
