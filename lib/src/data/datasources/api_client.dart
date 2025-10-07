import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/entities/folio_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/entities/paginated_reports.dart';
import '../../domain/entities/report.dart';
import '../../domain/value_objects/auth_token.dart';
import '../../utils/network/network_executor.dart';
import '../models/mappers.dart';

class ApiClient {
  ApiClient()
    : _dio = Dio(BaseOptions(baseUrl: 'https://example.citizenreports.mx')),
      _adminReports = List<Map<String, dynamic>>.generate(24, (index) {
        //1.- Generamos un set inicial de reportes para simular registros administrativos.
        final statusPool = ['en_revision', 'en_proceso', 'resuelto', 'critico'];
        final status = statusPool[index % statusPool.length];
        return {
          'id': 'F-${index.toString().padLeft(5, '0')}',
          'incidentType': {
            'id': index.isEven ? 'pothole' : 'lighting',
            'name': index.isEven ? 'Bache' : 'Alumbrado',
            'requiresEvidence': index.isEven,
          },
          'description': 'Reporte simulado número ${index + 1}',
          'latitude': 19.4 + index / 1000,
          'longitude': -99.1 - index / 1000,
          'status': status,
          'createdAt': DateTime.now()
              .subtract(Duration(hours: index * 3))
              .toIso8601String(),
        };
      });

  final Dio _dio;
  final NetworkExecutor _executor;
  final _random = Random();
  final List<Map<String, dynamic>> _adminReports;

  Future<AuthToken> authenticate({
    required String email,
    required String password,
  }) async {
    //1.- Simulamos la llamada al backend devolviendo un token con vigencia.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return AuthToken(
      'token-${email.hashCode}-${password.hashCode}',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
  }

  Future<List<IncidentType>> fetchIncidentTypes() async {
    //1.- Consultamos tipos remotos y convertimos las respuestas a entidades de dominio.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = [
      {'id': 'pothole', 'name': 'Bache', 'requiresEvidence': true},
      {
        'id': 'lighting',
        'name': 'Alumbrado público',
        'requiresEvidence': false,
      },
    ];
    //2.- Utilizamos el mapper para transformar mapas en objetos fuertemente tipados.
    return response.map(IncidentTypeMapper.fromMap).toList();
  }

  Future<Report> submitReport(Map<String, dynamic> payload) async {
    //1.- Simulamos la petición al backend creando un reporte con folio aleatorio.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final id = 'F-${_random.nextInt(99999).toString().padLeft(5, '0')}';
    final map = {
      'id': id,
      'incidentType': {
        'id': payload['incidentTypeId'],
        'name': 'Incidente',
        'requiresEvidence': false,
      },
      'description': payload['description'],
      'latitude': payload['latitude'],
      'longitude': payload['longitude'],
      'status': 'en_revision',
      'createdAt': DateTime.now().toIso8601String(),
    };
    //2.- Actualizamos el almacén local para que los reportes administrativos reflejen el nuevo caso.
    _adminReports.insert(0, map);
    //3.- Convertimos la respuesta a un Report para exponerlo a la capa de dominio.
    return ReportMapper.fromMap(map);
  }

  Future<FolioStatus> lookupFolio(String folio) async {
    //1.- Emulamos el endpoint de búsqueda devolviendo un historial breve.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final map = {
      'folio': folio,
      'status': 'en_proceso',
      'lastUpdate': DateTime.now().toIso8601String(),
      'history': ['Reporte recibido', 'Asignado a cuadrilla'],
    };
    //2.- Utilizamos el mapper dedicado para construir la entidad de dominio.
    return FolioStatusMapper.fromMap(map);
  }

  Future<AdminDashboardMetrics> fetchAdminDashboardMetrics() async {
    //1.- Calculamos métricas agregadas a partir de los reportes almacenados.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final pending = _adminReports
        .where((report) => report['status'] == 'en_revision')
        .length;
    final resolved = _adminReports
        .where((report) => report['status'] == 'resuelto')
        .length;
    final critical = _adminReports
        .where((report) => report['status'] == 'critico')
        .length;
    return AdminDashboardMetrics(
      pendingReports: pending,
      resolvedReports: resolved,
      criticalIncidents: critical,
    );
  }

  Future<PaginatedReports> fetchReportsPage({
    required int page,
    required int pageSize,
  }) async {
    //1.- Simulamos la paginación recortando la lista interna de reportes.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final start = page * pageSize;
    final end = min(start + pageSize, _adminReports.length);
    final slice = _adminReports.sublist(start, end);
    final hasMore = end < _adminReports.length;
    final items = slice.map(ReportMapper.fromMap).toList();
    return PaginatedReports(items: items, hasMore: hasMore, page: page);
  }

  Future<Report> fetchReportDetail(String id) async {
    //1.- Buscamos el reporte solicitado dentro de la colección simulada.
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final map = _adminReports.firstWhere(
      (report) => report['id'] == id,
      orElse: () {
        throw StateError('Reporte no encontrado');
      },
    );
    return ReportMapper.fromMap(map);
  }

  Future<Report> updateReportStatus({
    required String id,
    required String status,
  }) async {
    //1.- Actualizamos el estado del reporte seleccionado y devolvemos la versión actualizada.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final index = _adminReports.indexWhere((report) => report['id'] == id);
    if (index == -1) {
      throw StateError('Reporte no encontrado');
    }
    final updated = Map<String, dynamic>.from(_adminReports[index])
      ..['status'] = status;
    _adminReports[index] = updated;
    return ReportMapper.fromMap(updated);
  }

  Future<void> deleteReport(String id) async {
    //1.- Eliminamos el reporte de la lista simulada y notificamos éxito.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _adminReports.removeWhere((report) => report['id'] == id);
  }
}
