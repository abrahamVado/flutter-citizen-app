import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_reports_flutter/src/domain/entities/admin_dashboard_metrics.dart';
import 'package:citizen_reports_flutter/src/domain/entities/folio_status.dart';
import 'package:citizen_reports_flutter/src/domain/entities/incident_type.dart';
import 'package:citizen_reports_flutter/src/domain/entities/paginated_reports.dart';
import 'package:citizen_reports_flutter/src/domain/entities/report.dart';
import 'package:citizen_reports_flutter/src/domain/exceptions/validation_exception.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/reports_repository.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/submit_report.dart';

class _FakeReportsRepository implements ReportsRepository {
  _FakeReportsRepository();

  Report? lastRequest;

  @override
  Future<Report> submitReport(ReportRequest request) async {
    //1.- Registramos el request para verificar que pasó las validaciones.
    lastRequest = Report(
      id: 'F-00001',
      incidentType: IncidentType(
        id: request.incidentTypeId,
        name: 'Incidente',
        requiresEvidence: false,
      ),
      description: request.description,
      latitude: request.latitude,
      longitude: request.longitude,
      status: 'en_revision',
      createdAt: DateTime(2024, 1, 1),
    );
    //2.- Devolvemos un reporte simulado para que la capa superior continúe el flujo.
    return lastRequest!;
  }

  @override
  Future<FolioStatus> lookupFolio(String folio) {
    throw UnimplementedError();
  }

  @override
  Future<AdminDashboardMetrics> fetchDashboardMetrics() {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedReports> fetchReports({required int page, required int pageSize}) {
    throw UnimplementedError();
  }

  @override
  Future<Report> fetchReportById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteReport(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Report> updateReportStatus({required String id, required String status}) {
    throw UnimplementedError();
  }
}

void main() {
  group('SubmitReport', () {
    late SubmitReport useCase;
    late _FakeReportsRepository repository;

    setUp(() {
      repository = _FakeReportsRepository();
      useCase = SubmitReport(reportsRepository: repository);
    });

    test('envía el reporte cuando los datos son válidos', () async {
      final request = ReportRequest(
        incidentTypeId: 'pothole',
        description: 'Bache profundo frente a la escuela primaria.',
        contactEmail: 'vecino@example.com',
        contactPhone: '5512345678',
        latitude: 19.0,
        longitude: -99.0,
        address: 'Calle Reforma 123',
      );

      final report = await useCase(request);

      expect(report.id, equals('F-00001'));
    });

    test('lanza error cuando falta correo', () {
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Lampara sin funcionar en la esquina.',
        contactEmail: '',
        contactPhone: '5512345678',
        latitude: 19.0,
        longitude: -99.0,
        address: 'Calle Reforma 456',
      );

      expect(() => useCase(request), throwsA(isA<ValidationException>()));
    });

    test('lanza error cuando teléfono es corto', () {
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Lampara sin funcionar en la esquina.',
        contactEmail: 'vecino@example.com',
        contactPhone: '1234',
        latitude: 19.0,
        longitude: -99.0,
        address: 'Calle Reforma 456',
      );

      expect(() => useCase(request), throwsA(isA<ValidationException>()));
    });

    test('lanza error cuando descripción es corta', () {
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Muy corto',
        contactEmail: 'vecino@example.com',
        contactPhone: '5512345678',
        latitude: 19.0,
        longitude: -99.0,
        address: 'Calle Reforma 456',
      );

      expect(() => useCase(request), throwsA(isA<ValidationException>()));
    });
  });
}
