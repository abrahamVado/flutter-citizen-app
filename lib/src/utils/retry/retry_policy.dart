import 'dart:async';
import 'dart:math';

/// Política de reintento con backoff exponencial y jitter opcional.
class RetryPolicy {
  RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.backoffFactor = 2.0,
    this.jitterFactor = 0.25,
    bool Function(Object error)? shouldRetry,
    Future<void> Function(Duration delay)? wait,
    Random? random,
  }) : assert(maxAttempts > 0, 'Se requiere al menos un intento.'),
       assert(
         backoffFactor >= 1,
         'El factor de backoff debe ser mayor o igual a 1.',
       ),
       assert(
         jitterFactor >= 0 && jitterFactor <= 1,
         'El jitter debe estar entre 0 y 1.',
       ),
       _shouldRetry = shouldRetry,
       _wait = wait,
       _random = random;

  final int maxAttempts;
  final Duration initialDelay;
  final double backoffFactor;
  final double jitterFactor;
  final bool Function(Object error)? _shouldRetry;
  final Future<void> Function(Duration delay)? _wait;
  final Random? _random;

  /// Ejecuta la operación [action] respetando los parámetros configurados.
  Future<T> execute<T>(Future<T> Function(int attempt) action) async {
    //1.- Recorremos los intentos permitidos capturando el último error que se produzca.
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        //2.- Ejecutamos la acción delegando al consumidor la lógica dependiente del intento.
        return await action(attempt);
      } catch (error, stackTrace) {
        //3.- Evaluamos si corresponde reintentar o propagar el fallo inmediatamente.
        lastError = error;
        lastStackTrace = stackTrace;
        final canRetry = attempt < maxAttempts && canRetryOn(error);
        if (!canRetry) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        //4.- Esperamos el tiempo calculado antes de intentar nuevamente.
        await _waitForNextAttempt(attempt);
      }
    }
    //5.- Si se agotaron los intentos propagamos el último error registrado.
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  /// Expone si la política considera que un error amerita reintento.
  bool canRetryOn(Object error) {
    //1.- Consultamos el callback opcional; si no existe asumimos que se puede reintentar.
    return _shouldRetry?.call(error) ?? true;
  }

  Future<void> _waitForNextAttempt(int attempt) {
    //1.- Calculamos el retraso exponencial sumando un jitter aleatorio para evitar thundering herd.
    final duration = _delayFor(attempt);
    //2.- Elegimos el mecanismo de espera (inyectado en pruebas o `Future.delayed`).
    final handler = _wait ?? _defaultWait;
    return handler(duration);
  }

  Duration _delayFor(int attempt) {
    //1.- Calculamos el factor exponencial multiplicando por el número de incremento.
    final multiplier = pow(backoffFactor, attempt - 1).toDouble();
    final baseMillis = (initialDelay.inMilliseconds * multiplier).round();
    var millis = max(0, baseMillis);
    if (jitterFactor == 0) {
      return Duration(milliseconds: millis);
    }
    //2.- Obtenemos un valor aleatorio para ajustar hacia arriba o abajo el retraso base.
    final rand = _random ?? Random();
    final jitterMillis = (millis * jitterFactor * rand.nextDouble()).round();
    final sign = rand.nextBool() ? 1 : -1;
    millis += jitterMillis * sign;
    //3.- Garantizamos un retraso mínimo de cero milisegundos para evitar valores negativos.
    return Duration(milliseconds: max(0, millis));
  }

  static Future<void> _defaultWait(Duration delay) {
    //1.- Delegamos en `Future.delayed` respetando el retraso calculado.
    return Future<void>.delayed(delay);
  }
}
