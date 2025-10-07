import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_reports_flutter/src/utils/retry/retry_policy.dart';

void main() {
  test(
    'ejecuta reintentos con backoff exponencial hasta que tiene éxito',
    () async {
      //1.- Configuramos la política con backoff determinista para medir los retrasos.
      final delays = <Duration>[];
      var attempts = 0;
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 10),
        backoffFactor: 2,
        jitterFactor: 0,
        shouldRetry: (_) => true,
        wait: (delay) {
          delays.add(delay);
          return Future<void>.value();
        },
      );

      //2.- Ejecutamos una acción que falla hasta el último intento permitido.
      final result = await policy.execute<int>((_) async {
        attempts++;
        if (attempts < 3) {
          throw StateError('fallo temporal');
        }
        return 42;
      });

      //3.- Verificamos que se respetaron los reintentos y las esperas calculadas.
      expect(result, 42);
      expect(attempts, 3);
      expect(delays, const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20),
      ]);
    },
  );

  test(
    'propaga el error cuando la política indica que no debe reintentar',
    () async {
      //1.- Definimos la política para que rechace cualquier reintento.
      final policy = RetryPolicy(
        maxAttempts: 5,
        initialDelay: const Duration(milliseconds: 5),
        jitterFactor: 0,
        shouldRetry: (_) => false,
        wait: (_) => Future<void>.value(),
      );

      //2.- Verificamos que se propague el error original sin nuevos intentos.
      expect(
        () => policy.execute((_) async => throw ArgumentError('fatal')),
        throwsA(isA<ArgumentError>()),
      );
    },
  );
}
