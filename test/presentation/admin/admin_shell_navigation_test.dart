import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_reports_flutter/src/app/providers.dart';
import 'package:citizen_reports_flutter/src/domain/entities/admin_dashboard_metrics.dart';
import 'package:citizen_reports_flutter/src/domain/entities/folio_status.dart';
import 'package:citizen_reports_flutter/src/domain/entities/incident_type.dart';
import 'package:citizen_reports_flutter/src/domain/entities/paginated_reports.dart';
import 'package:citizen_reports_flutter/src/domain/entities/report.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/reports_repository.dart';
import 'package:citizen_reports_flutter/src/presentation/admin/admin_shell.dart';
import 'package:citizen_reports_flutter/src/presentation/admin/state/admin_navigation_controller.dart';

class _ShellReportsRepository implements ReportsRepository {
  const _ShellReportsRepository();

  Report get _sampleReport => Report(
        id: 'TEST-1',
        incidentType: const IncidentType(
          id: 'fire',
          name: 'Incendio',
          requiresEvidence: true,
        ),
        description: 'Simulación de incidente',
        latitude: 19.4,
        longitude: -99.1,
        status: 'en_revision',
        createdAt: DateTime(2024, 1, 1, 8),
      );

  @override
  Future<AdminDashboardMetrics> fetchDashboardMetrics() async {
    //1.- Entregamos métricas determinísticas para estabilizar las pruebas.
    return const AdminDashboardMetrics(
      pendingReports: 1,
      resolvedReports: 5,
      criticalIncidents: 0,
    );
  }

  @override
  Future<PaginatedReports> fetchReports({
    required int page,
    required int pageSize,
  }) async {
    //1.- Simulamos una respuesta paginada con un único reporte de ejemplo.
    return PaginatedReports(
      items: [_sampleReport],
      hasMore: false,
      page: page,
    );
  }

  @override
  Future<Report> fetchReportById(String id) async {
    //1.- Reutilizamos el mismo reporte para simplificar el escenario de prueba.
    return _sampleReport;
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

WidgetBuilder get _stubMapBuilder => (_) => const Placeholder(key: ValueKey('stub-map'));

void main() {
  testWidgets('muestra NavigationRail en pantallas amplias', (tester) async {
    //1.- Renderizamos el shell con un ancho suficiente para habilitar la barra lateral.
    await tester.pumpWidget(
      ProviderScope(
        overrides: const [
          reportsRepositoryProvider.overrideWithValue(_ShellReportsRepository()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: MaterialApp(
            home: AdminShell(privateMapBuilder: _stubMapBuilder),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('muestra NavigationBar en pantallas compactas', (tester) async {
    //1.- Reducimos el ancho disponible para activar la navegación inferior.
    await tester.pumpWidget(
      ProviderScope(
        overrides: const [
          reportsRepositoryProvider.overrideWithValue(_ShellReportsRepository()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: MaterialApp(
            home: AdminShell(privateMapBuilder: _stubMapBuilder),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('permite navegar a cada destino principal', (tester) async {
    //1.- Preparamos el entorno con repositorio simulado para alimentar las pantallas.
    await tester.pumpWidget(
      ProviderScope(
        overrides: const [
          reportsRepositoryProvider.overrideWithValue(_ShellReportsRepository()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: MaterialApp(
            home: AdminShell(privateMapBuilder: _stubMapBuilder),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    //2.- Abrimos el mapa privado y verificamos la presencia del encabezado.
    await tester.tap(find.byIcon(Icons.map_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Mapa privado de incidencias'), findsOneWidget);

    //3.- Navegamos al listado de reportes y comprobamos que el folio se muestre.
    await tester.tap(find.byIcon(Icons.assignment_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Folio TEST-1'), findsOneWidget);

    //4.- Movemos la navegación hacia la sección de configuración.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Configuración del panel'), findsOneWidget);

    //5.- Seleccionamos la vista de perfil para verificar su encabezado principal.
    await tester.tap(find.byIcon(Icons.person_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Mariana López'), findsOneWidget);

    //6.- Confirmamos que el estado global refleja la última selección realizada.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminShell)),
    );
    expect(container.read(adminNavigationProvider).route, AdminRoute.profile);
  });
}
