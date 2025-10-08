import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'private_map/admin_private_map_screen.dart';
import 'profile/admin_profile_screen.dart';
import 'reports/report_detail_screen.dart';
import 'reports/report_list_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'state/admin_navigation_controller.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, this.privateMapBuilder});

  final WidgetBuilder? privateMapBuilder;

  static final _navigatorKey = GlobalKey<NavigatorState>(
    //1.- Conservamos una única referencia para mantener el historial interno.
    debugLabel: 'admin-navigator',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Observamos el estado de navegación para determinar la ruta activa.
    final navigation = ref.watch(adminNavigationProvider);
    final navigatorController = ref.read(adminNavigationProvider.notifier);
    final mapBuilder = privateMapBuilder ?? AdminPrivateMapScreen.buildDefaultMap;
    final destinations = _AdminDestination.values;
    final selectedRoute = _AdminDestination.baseRouteFor(navigation.route);
    final selectedIndex = destinations.indexWhere(
      (destination) => destination.route == selectedRoute,
    );

    void handleDestinationSelection(int index) {
      //1.- Redirigimos el flujo según el destino elegido en el menú adaptable.
      final destination = destinations[index];
      switch (destination.route) {
        case AdminRoute.privateMap:
          navigatorController.goToPrivateMap();
          break;
        case AdminRoute.dashboard:
          navigatorController.goToDashboard();
          break;
        case AdminRoute.reports:
          navigatorController.goToReports();
          break;
        case AdminRoute.settings:
          navigatorController.goToSettings();
          break;
        case AdminRoute.profile:
          navigatorController.goToProfile();
          break;
        case AdminRoute.reportDetail:
          break;
      }
    }

    final navigatorWidget = _AdminNavigator(
      navigation: navigation,
      controller: navigatorController,
      navigatorKey: _navigatorKey,
      mapBuilder: mapBuilder,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        //1.- Adaptamos el contenedor según el ancho disponible para mejorar la usabilidad.
        final useRail = constraints.maxWidth >= 900;
        final safeSelectedIndex = selectedIndex >= 0 ? selectedIndex : 1;

        if (useRail) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Panel administrativo'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    //1.- Cerramos la sesión actual sin abandonar la sección en pantalla.
                    ref.read(sessionControllerProvider.notifier).signOut();
                  },
                  tooltip: 'Cerrar sesión',
                ),
              ],
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: safeSelectedIndex,
                  onDestinationSelected: handleDestinationSelection,
                  extended: constraints.maxWidth >= 1200,
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigatorWidget),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel administrativo'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  //1.- Habilitamos el cierre de sesión desde dispositivos compactos.
                  ref.read(sessionControllerProvider.notifier).signOut();
                },
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
          body: navigatorWidget,
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeSelectedIndex,
            onDestinationSelected: handleDestinationSelection,
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  label: destination.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminNavigator extends StatelessWidget {
  const _AdminNavigator({
    required this.navigation,
    required this.controller,
    required this.navigatorKey,
    required this.mapBuilder,
  });

  final AdminNavigationState navigation;
  final AdminNavigationController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder mapBuilder;

  @override
  Widget build(BuildContext context) {
    //1.- Construimos la pila de navegación interna respetando el flujo seleccionado.
    final pages = <Page<void>>[
      const MaterialPage(
        key: ValueKey('admin-dashboard-page'),
        child: AdminDashboardScreen(),
      ),
    ];

    switch (navigation.route) {
      case AdminRoute.dashboard:
        break;
      case AdminRoute.reports:
        pages.add(
          MaterialPage(
            key: const ValueKey('admin-report-list-page'),
            child: ReportListScreen(
              onReportSelected: controller.openReportDetail,
            ),
          ),
        );
        break;
      case AdminRoute.reportDetail:
        pages.add(
          MaterialPage(
            key: const ValueKey('admin-report-list-page'),
            child: ReportListScreen(
              onReportSelected: controller.openReportDetail,
            ),
          ),
        );
        if (navigation.selectedReportId != null) {
          pages.add(
            MaterialPage(
              key: ValueKey('admin-report-detail-${navigation.selectedReportId}'),
              child: ReportDetailScreen(
                reportId: navigation.selectedReportId!,
              ),
            ),
          );
        }
        break;
      case AdminRoute.privateMap:
        pages.add(
          MaterialPage(
            key: const ValueKey('admin-private-map-page'),
            child: AdminPrivateMapScreen(mapBuilder: mapBuilder),
          ),
        );
        break;
      case AdminRoute.settings:
        pages.add(
          const MaterialPage(
            key: ValueKey('admin-settings-page'),
            child: AdminSettingsScreen(),
          ),
        );
        break;
      case AdminRoute.profile:
        pages.add(
          const MaterialPage(
            key: ValueKey('admin-profile-page'),
            child: AdminProfileScreen(),
          ),
        );
        break;
    }

    return Navigator(
      key: navigatorKey,
      pages: pages,
      onPopPage: (route, result) {
        //1.- Sincronizamos el estado global cuando se solicita regresar en la pila interna.
        if (!route.didPop(result)) {
          return false;
        }
        return controller.handlePop();
      },
    );
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.route,
    required this.icon,
    required this.label,
  });

  final AdminRoute route;
  final IconData icon;
  final String label;

  static List<_AdminDestination> get values => const [
        _AdminDestination(
          route: AdminRoute.privateMap,
          icon: Icons.map_outlined,
          label: 'Mapa privado',
        ),
        _AdminDestination(
          route: AdminRoute.dashboard,
          icon: Icons.dashboard_outlined,
          label: 'Tablero',
        ),
        _AdminDestination(
          route: AdminRoute.reports,
          icon: Icons.assignment_outlined,
          label: 'Reportes',
        ),
        _AdminDestination(
          route: AdminRoute.settings,
          icon: Icons.settings_outlined,
          label: 'Configuración',
        ),
        _AdminDestination(
          route: AdminRoute.profile,
          icon: Icons.person_outline,
          label: 'Perfil',
        ),
      ];

  static AdminRoute baseRouteFor(AdminRoute route) {
    //1.- Normalizamos rutas secundarias para mantener la selección en la navegación.
    if (route == AdminRoute.reportDetail) {
      return AdminRoute.reports;
    }
    return route;
  }
}
