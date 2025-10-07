import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/entities/folio_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/entities/report.dart';
import '../../domain/value_objects/auth_token.dart';
import '../models/mappers.dart';

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? 'http://127.0.0.1:8080',
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 5),
              ),
            );

  final Dio _dio;

  Future<AuthToken> authenticate({required String email, required String password}) {
    //1.- Ejecutamos la petición POST delegando el manejo de errores al helper.
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth',
        data: {'email': email, 'password': password},
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data == null || data['token'] == null || data['expiresAt'] == null) {
        throw const ApiClientException('Respuesta inválida del servicio de autenticación');
      }
      //2.- Convertimos la respuesta cruda en el objeto de dominio esperado.
      return AuthToken(
        data['token'] as String,
        expiresAt: DateTime.parse(data['expiresAt'] as String),
      );
    });
  }

  Future<List<IncidentType>> fetchIncidentTypes() {
    //1.- Realizamos la lectura del catálogo y aprovechamos que Dio soporta concurrencia segura.
    return _guard(() async {
      final response = await _dio.get<List<dynamic>>(
        '/catalog',
        options: Options(responseType: ResponseType.json),
      );
      final items = response.data;
      if (items == null) {
        throw const ApiClientException('Catálogo vacío recibido del backend');
      }
      //2.- Convertimos cada entrada en la entidad de dominio correspondiente.
      return items
          .cast<Map<String, dynamic>>()
          .map(IncidentTypeMapper.fromMap)
          .toList(growable: false);
    });
  }

  Future<Report> submitReport(Map<String, dynamic> payload) {
    //1.- Serializamos la solicitud y esperamos el reporte creado por el worker pool Go.
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reports',
        data: payload,
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data == null) {
        throw const ApiClientException('El backend no devolvió información del reporte');
      }
      //2.- Usamos el mapper para exponer la respuesta a capas superiores.
      return ReportMapper.fromMap(data);
    });
  }

  Future<FolioStatus> lookupFolio(String folio) {
    //1.- Consultamos el folio en paralelo a otras solicitudes activas.
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/folios/$folio',
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data == null) {
        throw ApiClientException('Folio $folio sin información remota');
      }
      //2.- Traducimos la carga útil en la entidad que la UI entiende.
      return FolioStatusMapper.fromMap(data);
    });
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    //1.- Centralizamos la captura de errores para todas las solicitudes HTTP.
    try {
      return await run().timeout(const Duration(seconds: 10));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final message = _resolveErrorMessage(error);
      throw ApiClientException(message, statusCode: status);
    } on TimeoutException {
      throw const ApiClientException('Tiempo de espera agotado al contactar el backend');
    }
  }

  String _resolveErrorMessage(DioException error) {
    //1.- Preferimos mensajes específicos del backend en caso de existir.
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'] ?? responseData['error'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return 'Error de red inesperado';
  }
}

class ApiClientException implements Exception {
  const ApiClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiClientException($statusCode): $message';
}
