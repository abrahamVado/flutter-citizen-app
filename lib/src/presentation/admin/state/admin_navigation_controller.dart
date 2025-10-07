import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdminRoute { dashboard, reportList, reportDetail }

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

  void goToReportList() {
    //1.- Mostramos la tabla con el historial completo de reportes.
    state = const AdminNavigationState(route: AdminRoute.reportList);
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
      goToReportList();
      return true;
    }
    if (state.route == AdminRoute.reportList) {
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
