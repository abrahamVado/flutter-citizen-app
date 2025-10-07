import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:citizen_reports_flutter/src/domain/entities/admin_dashboard_metrics.dart';
import 'package:citizen_reports_flutter/src/domain/entities/folio_status.dart';
import 'package:citizen_reports_flutter/src/domain/entities/incident_type.dart';
import 'package:citizen_reports_flutter/src/domain/entities/paginated_reports.dart';
import 'package:citizen_reports_flutter/src/domain/entities/report.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/reports_repository.dart';
import 'package:citizen_reports_flutter/src/presentation/admin/reports/report_list_screen.dart';
import 'package:citizen_reports_flutter/src/presentation/admin/state/admin_reports_providers.dart';
import 'package:citizen_reports_flutter/src/app/providers.dart';

class _PaginatedReportsRepository implements ReportsRepository {
  _PaginatedReportsRepository()
    : _reports = List.generate(
        15,
        (index) => Report(
          id: 'F-${index.toString().padLeft(5, '0')}',
          incidentType: const IncidentType(
            id: 'lighting',
            name: 'Alumbrado',
            requiresEvidence: false,
          ),
          description: 'Reporte $index',
          latitude: 19.0,
          longitude: -99.0,
          status: index.isEven ? 'en_revision' : 'resuelto',
          createdAt: DateTime(2024, 1, 1).add(Duration(hours: index)),
        ),
      );

  final List<Report> _reports;

  @override
  Future<PaginatedReports> fetchReports({
    required int page,
    required int pageSize,
  }) async {
    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, _reports.length) as int;
    final slice = _reports.sublist(start, end);
    final hasMore = end < _reports.length;
    return PaginatedReports(items: slice, hasMore: hasMore, page: page);
  }

  @override
  Future<AdminDashboardMetrics> fetchDashboardMetrics() {
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
  testWidgets('muestra paginación y permite cargar más elementos', (
    tester,
  ) async {
    //1.- Inyectamos un repositorio con quince reportes simulados.
    final repository = _PaginatedReportsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: ReportListScreen(onReportSelected: (_) {})),
      ),
    );

    //2.- Esperamos a que se construya la lista inicial.
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReportListScreen)),
    );

    expect(find.textContaining('Folio F-00000'), findsOneWidget);
    expect(container.read(adminReportsListProvider).items.length, 10);

    //3.- Disparamos la carga adicional a través del botón "Cargar más".
    await container.read(adminReportsListProvider.notifier).loadMore();
    await tester.pumpAndSettle();

    expect(container.read(adminReportsListProvider).items.length, 15);
    expect(find.text('Cargar más'), findsNothing);
  });
}
