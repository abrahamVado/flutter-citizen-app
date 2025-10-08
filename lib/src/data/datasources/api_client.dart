import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/entities/folio_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/entities/paginated_reports.dart';
import '../../domain/entities/report.dart';
import '../../domain/value_objects/auth_token.dart';
import '../../domain/value_objects/social_provider.dart';
// Removed: '../../utils/network/network_executor.dart'
import '../models/mappers.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(BaseOptions(baseUrl: 'https://example.citizenreports.mx')),
        _adminReports = List<Map<String, dynamic>>.generate(24, (index) {
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
  final math.Random _random = math.Random();
  final List<Map<String, dynamic>> _adminReports;

  Future<AuthToken> authenticate({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return AuthToken(
      'token-${email.hashCode}-${password.hashCode}',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
  }

  Future<AuthToken> register({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return AuthToken(
      'reg-${email.hashCode}-${password.hashCode}',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
  }

  Future<void> recoverPassword({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!email.contains('@')) {
      throw DioException(
        requestOptions: RequestOptions(path: '/recover'),
        message: 'Correo inválido',
      );
    }
  }

  Future<AuthToken> signInWithProvider({required SocialProvider provider}) async {
    await Future<void>.delayed(const Duration(milliseconds: 210));
    return AuthToken(
      'social-${provider.id}-${_random.nextInt(999999)}',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
  }

  Future<List<IncidentType>> fetchIncidentTypes() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = [
      {'id': 'pothole', 'name': 'Bache', 'requiresEvidence': true},
      {'id': 'lighting', 'name': 'Alumbrado público', 'requiresEvidence': false},
    ];
    return response.map(IncidentTypeMapper.fromMap).toList();
  }

  Future<Report> submitReport(Map<String, dynamic> payload) async {
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
    _adminReports.insert(0, map);
    return ReportMapper.fromMap(map);
  }

  Future<FolioStatus> lookupFolio(String folio) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final map = {
      'folio': folio,
      'status': 'en_proceso',
      'lastUpdate': DateTime.now().toIso8601String(),
      'history': ['Reporte recibido', 'Asignado a cuadrilla'],
    };
    return FolioStatusMapper.fromMap(map);
  }

  Future<AdminDashboardMetrics> fetchAdminDashboardMetrics() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final pending =
        _adminReports.where((r) => r['status'] == 'en_revision').length;
    final resolved =
        _adminReports.where((r) => r['status'] == 'resuelto').length;
    final critical =
        _adminReports.where((r) => r['status'] == 'critico').length;
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
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final start = page * pageSize; // if your pages are 0-based
    // If pages are 1-based, use: final start = (page - 1) * pageSize;
    final end = math.min(start + pageSize, _adminReports.length);
    if (start >= _adminReports.length) {
      return PaginatedReports(items: const [], hasMore: false, page: page);
    }
    final slice = _adminReports.sublist(start, end);
    final hasMore = end < _adminReports.length;
    final items = slice.map(ReportMapper.fromMap).toList();
    return PaginatedReports(items: items, hasMore: hasMore, page: page);
  }

  Future<Report> fetchReportDetail(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final map = _adminReports.firstWhere(
      (report) => report['id'] == id,
      orElse: () => throw StateError('Reporte no encontrado'),
    );
    return ReportMapper.fromMap(map);
  }

  Future<Report> updateReportStatus({
    required String id,
    required String status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final index = _adminReports.indexWhere((r) => r['id'] == id);
    if (index == -1) throw StateError('Reporte no encontrado');
    final updated = Map<String, dynamic>.from(_adminReports[index])
      ..['status'] = status;
    _adminReports[index] = updated;
    return ReportMapper.fromMap(updated);
  }

  Future<void> deleteReport(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _adminReports.removeWhere((r) => r['id'] == id);
  }
}
