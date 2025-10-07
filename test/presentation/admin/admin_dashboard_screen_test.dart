import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:citizen_reports_flutter/src/domain/entities/admin_dashboard_metrics.dart';
import 'package:citizen_reports_flutter/src/domain/entities/folio_status.dart';
import 'package:citizen_reports_flutter/src/domain/entities/paginated_reports.dart';
import 'package:citizen_reports_flutter/src/domain/entities/report.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/reports_repository.dart';
import 'package:citizen_reports_flutter/src/presentation/admin/dashboard/admin_dashboard_screen.dart';
import 'package:citizen_reports_flutter/src/presentation/admin/state/admin_navigation_controller.dart';
import 'package:citizen_reports_flutter/src/app/providers.dart';

class _DashboardReportsRepository implements ReportsRepository {
  @override
  Future<AdminDashboardMetrics> fetchDashboardMetrics() async {
    return const AdminDashboardMetrics(
      pendingReports: 7,
      resolvedReports: 21,
      criticalIncidents: 2,
    );
  }

  @override
  Future<PaginatedReports> fetchReports({
    required int page,
    required int pageSize,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Report> fetchReportById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Report> updateReportStatus({
    required String id,
    required String status,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteReport(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Report> submitReport(ReportRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<FolioStatus> lookupFolio(String folio) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('muestra métricas reales y navega al listado', (tester) async {
    //1.- Inyectamos un repositorio controlado para devolver métricas determinísticas.
    final repository = _DashboardReportsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );

    //2.- Avanzamos un frame para que se resuelva el FutureProvider con las métricas.
    await tester.pump();

    expect(find.text('Reportes pendientes'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    //3.- Recuperamos el contenedor para validar la navegación cuando se presiona el botón.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminDashboardScreen)),
    );

    await tester.tap(find.text('Ver listado completo'));
    await tester.pump();

    expect(
      container.read(adminNavigationProvider).route,
      AdminRoute.reportList,
    );
  });
}
