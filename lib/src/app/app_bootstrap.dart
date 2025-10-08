import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';

Future<void> bootstrapApplication(Widget root) async {
  //1.- Garantizamos la inicialización temprana del engine para habilitar canales nativos.
  WidgetsFlutterBinding.ensureInitialized();
  //2.- Construimos las dependencias compartidas que serán inyectadas mediante Riverpod.
  final overrides = await buildAppOverrides();
  //3.- Ejecutamos la aplicación envolviéndola en un ProviderScope que aplica los overrides configurados.
  runApp(
    ProviderScope(
      overrides: overrides,
      child: root,
    ),
  );
}
