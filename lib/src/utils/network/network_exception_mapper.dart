import 'dart:async';

import 'package:dio/dio.dart';

/// Excepción estandarizada para fallos de red.
class NetworkException implements Exception {
  NetworkException(
    this.message, {
    this.statusCode,
    this.isRetriable = false,
    this.innerError,
  });

  final String message;
  final int? statusCode;
  final bool isRetriable;
  final Object? innerError;

  @override
  String toString() =>
      'NetworkException(message: $message, statusCode: $statusCode, isRetriable: $isRetriable)';
}

/// Convierte errores de librerías HTTP en [NetworkException].
class NetworkExceptionMapper {
  const NetworkExceptionMapper();

  NetworkException map(Object error, {StackTrace? stackTrace}) {
    //1.- Reutilizamos la excepción si ya viene normalizada desde otra capa.
    if (error is NetworkException) {
      return error;
    }
    //2.- Interpretamos fallos generados por Dio para propagar metadatos relevantes.
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final isTimeout =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
      final retriable = isTimeout || (statusCode != null && statusCode >= 500);
      final message = error.message ?? 'Error de red';
      return NetworkException(
        message,
        statusCode: statusCode,
        isRetriable: retriable,
        innerError: error,
      );
    }
    //3.- Clasificamos los `TimeoutException` genéricos como eventos reintetables.
    if (error is TimeoutException) {
      return NetworkException(
        'Tiempo de espera agotado',
        isRetriable: true,
        innerError: error,
      );
    }
    //4.- Cualquier otro error se marca como no reintetable para propagar la causa raíz.
    return NetworkException(
      'Error de red inesperado',
      isRetriable: false,
      innerError: error,
    );
  }
}
