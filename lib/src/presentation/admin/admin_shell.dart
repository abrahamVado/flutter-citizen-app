import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'reports/report_detail_screen.dart';
import 'reports/report_list_screen.dart';
import 'state/admin_navigation_controller.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>(
    //1.- Conservamos una única referencia para mantener el historial interno.
    debugLabel: 'admin-navigator',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Observamos el estado de navegación para determinar las rutas activas.
    final navigation = ref.watch(adminNavigationProvider);
    final navigatorController = ref.read(adminNavigationProvider.notifier);
    //2.- Renderizamos la estructura base con navegación anidada para el panel administrativo.
    return Scaffold(
      appBar: AppBar(title: const Text('Panel administrativo')),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(child: Text('Citizen Reports')),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Dashboard'),
              selected: navigation.route == AdminRoute.dashboard,
              onTap: () {
                //1.- Cerramos el menú lateral y navegamos a la pantalla principal.
                Navigator.of(context).pop();
                navigatorController.goToDashboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Reportes'),
              selected: navigation.route == AdminRoute.reportList ||
                  navigation.route == AdminRoute.reportDetail,
              onTap: () {
                //1.- Cerramos el menú lateral y navegamos al listado de reportes.
                Navigator.of(context).pop();
                navigatorController.goToReportList();
              },
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
      body: Navigator(
        key: _navigatorKey,
        //1.- Construimos la pila de páginas en función del estado del controlador.
        pages: [
          const MaterialPage(
            key: ValueKey('admin-dashboard-page'),
            child: AdminDashboardScreen(),
          ),
          if (navigation.route == AdminRoute.reportList ||
              navigation.route == AdminRoute.reportDetail)
            MaterialPage(
              key: const ValueKey('admin-report-list-page'),
              child: ReportListScreen(
                onReportSelected: navigatorController.openReportDetail,
              ),
            ),
          if (navigation.route == AdminRoute.reportDetail &&
              navigation.selectedReportId != null)
            MaterialPage(
              key: ValueKey('admin-report-detail-${navigation.selectedReportId}'),
              child: ReportDetailScreen(reportId: navigation.selectedReportId!),
            ),
        ],
        onPopPage: (route, result) {
          //1.- Intentamos cerrar la ruta actual y sincronizamos el estado global.
          if (!route.didPop(result)) {
            return false;
          }
          return navigatorController.handlePop();
        },
      ),
    );
  }
}
