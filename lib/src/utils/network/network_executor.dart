import '../retry/retry_policy.dart';
import 'network_exception_mapper.dart';

/// Ejecuta operaciones de red aplicando reintentos y mapeo de excepciones.
class NetworkExecutor {
  NetworkExecutor({
    RetryPolicy? retryPolicy,
    NetworkExceptionMapper? exceptionMapper,
  }) : _exceptionMapper = exceptionMapper ?? const NetworkExceptionMapper(),
       _retryPolicy =
           retryPolicy ??
           RetryPolicy(
             shouldRetry: (error) =>
                 error is NetworkException ? error.isRetriable : false,
           );

  final NetworkExceptionMapper _exceptionMapper;
  final RetryPolicy _retryPolicy;

  /// Ejecuta [task] normalizando errores y aplicando la política de reintentos.
  Future<T> run<T>(Future<T> Function() task) {
    //1.- Deferimos la ejecución a la política para reutilizar la lógica de backoff.
    return _retryPolicy.execute((_) async {
      try {
        //2.- Ejecutamos la tarea original y regresamos su resultado intacto.
        return await task();
      } catch (error, stackTrace) {
        //3.- Traducimos el error capturado a `NetworkException` antes de decidir reintentos.
        final mapped = _exceptionMapper.map(error, stackTrace: stackTrace);
        //4.- Propagamos el error con su `StackTrace` original para no perder contexto.
        Error.throwWithStackTrace(mapped, stackTrace);
      }
    });
  }

  /// Ejecuta [task] y entrega un [fallback] en caso de falla controlada.
  Future<T> runWithFallback<T>(
    Future<T> Function() task, {
    T Function(NetworkException error)? fallback,
  }) async {
    //1.- Ejecutamos la tarea principal reutilizando la política de reintentos.
    try {
      return await run(task);
    } on NetworkException catch (error) {
      //2.- Si hay alternativa registrada la regresamos, de lo contrario propagamos el error.
      if (fallback != null) {
        return fallback(error);
      }
      rethrow;
    }
  }
}
