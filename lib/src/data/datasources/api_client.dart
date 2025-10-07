import 'dart:math';

import 'package:dio/dio.dart';

import '../../domain/entities/folio_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/entities/report.dart';
import '../../domain/value_objects/auth_token.dart';
import '../models/mappers.dart';

class ApiClient {
  ApiClient() : _dio = Dio(BaseOptions(baseUrl: 'https://example.citizenreports.mx'));

  final Dio _dio;
  final _random = Random();

  Future<AuthToken> authenticate({required String email, required String password}) async {
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
      {'id': 'lighting', 'name': 'Alumbrado público', 'requiresEvidence': false},
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
    //2.- Convertimos la respuesta a un Report para exponerlo a la capa de dominio.
    return ReportMapper.fromMap(map);
  }

  Future<FolioStatus> lookupFolio(String folio) async {
    //1.- Emulamos el endpoint de búsqueda devolviendo un historial breve.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final map = {
      'folio': folio,
      'status': 'en_proceso',
      'lastUpdate': DateTime.now().toIso8601String(),
      'history': [
        'Reporte recibido',
        'Asignado a cuadrilla',
      ],
    };
    //2.- Utilizamos el mapper dedicado para construir la entidad de dominio.
    return FolioStatusMapper.fromMap(map);
  }
}
