import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/admin/admin_shell.dart';
import '../presentation/design/shadcn/shadcn_theme.dart';
import '../presentation/public/auth/auth_screen.dart';
import 'state/session_controller.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Escuchamos la sesión global para decidir si debemos pedir credenciales o mostrar el panel administrativo.
    final session = ref.watch(sessionControllerProvider);
    //2.- Reutilizamos el mismo tema visual para mantener consistencia entre las experiencias.
    final theme = ShadcnTheme.build();
    //3.- Construimos un MaterialApp que intercambia su pantalla inicial según el estado de sesión observado.
    return MaterialApp(
      title: 'Citizen Reports Admin',
      theme: theme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (session.status) {
          SessionStatus.authenticated => const AdminShell(),
          SessionStatus.initializing => const _FullScreenLoader(),
          SessionStatus.error => _SessionError(error: session.errorMessage ?? 'Error de sesión'),
          SessionStatus.signedOut => const AuthScreen(),
        },
      ),
    );
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    //1.- Mostramos un indicador de carga de pantalla completa mientras se procesan las credenciales del usuario.
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
    //1.- Renderizamos el mensaje de error y permitimos limpiar la sesión para reintentar el flujo.
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
