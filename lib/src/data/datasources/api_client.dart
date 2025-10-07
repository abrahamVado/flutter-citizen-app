import 'dart:math';

import 'package:dio/dio.dart';

import '../../domain/entities/folio_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/entities/report.dart';
import '../../domain/value_objects/auth_token.dart';
import '../../utils/network/network_executor.dart';
import '../models/mappers.dart';

class ApiClient {
  ApiClient({Dio? dio, NetworkExecutor? executor})
    : _dio =
          dio ?? Dio(BaseOptions(baseUrl: 'https://example.citizenreports.mx')),
      _executor = executor ?? NetworkExecutor();

  final Dio _dio;
  final NetworkExecutor _executor;
  final _random = Random();

  Future<AuthToken> authenticate({
    required String email,
    required String password,
  }) {
    //1.- Delegamos el request al ejecutor resiliente para reutilizar reintentos y mapeo de errores.
    return _executor.run(() async {
      //2.- Simulamos la llamada al backend devolviendo un token con vigencia.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return AuthToken(
        'token-${email.hashCode}-${password.hashCode}',
        expiresAt: DateTime.now().add(const Duration(hours: 8)),
      );
    });
  }

  Future<List<IncidentType>> fetchIncidentTypes() {
    //1.- Utilizamos el ejecutor para encapsular backoff y normalización de errores.
    return _executor.run(() async {
      //2.- Consultamos tipos remotos y convertimos las respuestas a entidades de dominio.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final response = [
        {'id': 'pothole', 'name': 'Bache', 'requiresEvidence': true},
        {
          'id': 'lighting',
          'name': 'Alumbrado público',
          'requiresEvidence': false,
        },
      ];
      //3.- Utilizamos el mapper para transformar mapas en objetos fuertemente tipados.
      return response.map(IncidentTypeMapper.fromMap).toList();
    });
  }

  Future<Report> submitReport(Map<String, dynamic> payload) {
    //1.- Encapsulamos la petición dentro del ejecutor resiliente.
    return _executor.run(() async {
      //2.- Simulamos la petición al backend creando un reporte con folio aleatorio.
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
      //3.- Convertimos la respuesta a un Report para exponerlo a la capa de dominio.
      return ReportMapper.fromMap(map);
    });
  }

  Future<FolioStatus> lookupFolio(String folio) {
    //1.- Ejecutamos la consulta a través del helper que administra reintentos y errores.
    return _executor.run(() async {
      //2.- Emulamos el endpoint de búsqueda devolviendo un historial breve.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final map = {
        'folio': folio,
        'status': 'en_proceso',
        'lastUpdate': DateTime.now().toIso8601String(),
        'history': ['Reporte recibido', 'Asignado a cuadrilla'],
      };
      //3.- Utilizamos el mapper dedicado para construir la entidad de dominio.
      return FolioStatusMapper.fromMap(map);
    });
  }
}
