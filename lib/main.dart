import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/bootstrap.dart';
import 'src/app/citizen_reports_app.dart';

Future<void> main() async {
  //1.- Garantizamos la inicialización del motor de Flutter para preparar los servicios nativos.
  WidgetsFlutterBinding.ensureInitialized();
  //2.- Construimos las dependencias iniciales leyendo caches y configuraciones remotas.
  final overrides = await buildAppOverrides();
  //3.- Lanzamos la aplicación dentro de un ProviderScope que inyecta los repositorios configurados.
  runApp(
    ProviderScope(
      overrides: overrides,
      child: const CitizenReportsApp(),
    ),
  );
}
