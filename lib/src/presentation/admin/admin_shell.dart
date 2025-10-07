import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'dashboard/admin_dashboard_screen.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Renderizamos una estructura básica con menú lateral para futuras pantallas administrativas.
    return Scaffold(
      appBar: AppBar(title: const Text('Panel administrativo')),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(child: Text('Citizen Reports')),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Dashboard'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                //1.- Notificamos al controlador de sesión para invalidar el token.
                ref.read(sessionControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
      body: const AdminDashboardScreen(),
    );
  }
}
