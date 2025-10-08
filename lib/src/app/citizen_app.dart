import 'package:flutter/material.dart';

import '../presentation/design/shadcn/shadcn_theme.dart';
import '../presentation/public/public_shell.dart';

class CitizenApp extends StatelessWidget {
  const CitizenApp({super.key});

  @override
  Widget build(BuildContext context) {
    //1.- Construimos el tema visual compartido utilizando la implementación basada en shadcn/ui.
    final theme = ShadcnTheme.build();
    //2.- Exponemos un MaterialApp simplificado que inicia directamente en la navegación pública.
    return MaterialApp(
      title: 'Citizen Reports',
      theme: theme,
      home: const PublicShell(),
    );
  }
}
