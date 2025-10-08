import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdminRoute {
  dashboard,
  reports,
  reportDetail,
  privateMap,
  settings,
  profile,
}

class AdminNavigationState {
  const AdminNavigationState({
    this.route = AdminRoute.dashboard,
    this.selectedReportId,
  });

  //1.- Representa la pantalla actual dentro del flujo administrativo.
  final AdminRoute route;
  //2.- Conserva el identificador del reporte cuando navegamos al detalle.
  final String? selectedReportId;

  AdminNavigationState copyWith({AdminRoute? route, String? selectedReportId}) {
    //1.- Permitimos crear variaciones del estado para mantener la inmutabilidad.
    return AdminNavigationState(
      route: route ?? this.route,
      selectedReportId: selectedReportId ?? this.selectedReportId,
    );
  }
}

class AdminNavigationController extends StateNotifier<AdminNavigationState> {
  AdminNavigationController() : super(const AdminNavigationState());

  void goToDashboard() {
    //1.- Regresamos a la pantalla principal del panel administrativo.
    state = const AdminNavigationState(route: AdminRoute.dashboard);
  }

  void goToReports() {
    //1.- Mostramos la tabla con el historial completo de reportes.
    state = const AdminNavigationState(route: AdminRoute.reports);
  }

  void goToPrivateMap() {
    //1.- Cargamos el mapa privado para visualizar la distribución geográfica.
    state = const AdminNavigationState(route: AdminRoute.privateMap);
  }

  void goToSettings() {
    //1.- Abrimos el módulo de configuración del panel administrativo.
    state = const AdminNavigationState(route: AdminRoute.settings);
  }

  void goToProfile() {
    //1.- Permitimos que la persona administradora revise y edite su perfil.
    state = const AdminNavigationState(route: AdminRoute.profile);
  }

  void openReportDetail(String reportId) {
    //1.- Abrimos la vista de detalle conservando el folio seleccionado.
    state = AdminNavigationState(
      route: AdminRoute.reportDetail,
      selectedReportId: reportId,
    );
  }

  bool handlePop() {
    //1.- Interceptamos la navegación hacia atrás para movernos entre pantallas anidadas.
    if (state.route == AdminRoute.reportDetail) {
      goToReports();
      return true;
    }
    if (state.route == AdminRoute.reports) {
      goToDashboard();
      return true;
    }
    if (state.route == AdminRoute.privateMap ||
        state.route == AdminRoute.settings ||
        state.route == AdminRoute.profile) {
      goToDashboard();
      return true;
    }
    return false;
  }
}

final adminNavigationProvider =
    StateNotifierProvider<AdminNavigationController, AdminNavigationState>((
      ref,
    ) {
      //1.- Exponemos el controlador a toda la jerarquía de widgets administrativos.
      return AdminNavigationController();
    });
