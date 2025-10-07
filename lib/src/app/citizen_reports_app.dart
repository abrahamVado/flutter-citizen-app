import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/admin/admin_shell.dart';
import '../presentation/public/public_shell.dart';
import 'providers.dart';
import 'state/session_controller.dart';

class CitizenReportsApp extends ConsumerWidget {
  const CitizenReportsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Observamos el estado de sesión para decidir qué grafo de navegación mostrar.
    final session = ref.watch(sessionControllerProvider);
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0066CC)),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Citizen Reports',
      theme: theme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (session.status) {
          SessionStatus.authenticated => const AdminShell(),
          SessionStatus.initializing => const _FullScreenLoader(),
          SessionStatus.error => _SessionError(error: session.errorMessage ?? 'Error de sesión'),
          _ => const PublicShell(),
        },
      ),
    );
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    //1.- Mostramos un loader simple mientras se ejecutan procesos de autenticación.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SessionError extends ConsumerWidget {
  const _SessionError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Exponemos el error y permitimos reintentar un inicio de sesión limpio.
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
                child: const Text('Intentar de nuevo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
