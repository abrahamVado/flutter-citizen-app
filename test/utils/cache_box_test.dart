import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_reports_flutter/src/data/cache/local_cache.dart';
import 'package:citizen_reports_flutter/src/utils/cache/cache_box.dart';
import 'package:citizen_reports_flutter/src/utils/cache/concurrency_safe_cache.dart';

void main() {
  group('CacheBox', () {
    test('serializa mutaciones concurrentes garantizando consistencia', () async {
      //1.- Configuramos una caché en memoria envuelta por el candado secuencial.
      final cache = InMemoryLocalCache();
      final safeCache = ConcurrencySafeCache(cache);
      final box = CacheBox<int>(
        cache: safeCache,
        key: 'counter',
        encode: (value) => {'value': value},
        decode: (map) => map['value'] as int,
      );

      //2.- Disparamos múltiples mutaciones en paralelo incrementando el contador.
      await Future.wait(
        List.generate(10, (index) {
          return box.mutate((current, save, clear) async {
            final next = (current ?? 0) + 1;
            save(next);
            return null;
          });
        }),
      );

      //3.- Validamos que el valor final corresponda al número de mutaciones ejecutadas.
      expect(await box.read(), 10);
    });

    test('permite limpiar la entrada desde una mutación controlada', () async {
      //1.- Inicializamos la caché con un valor existente.
      final cache = InMemoryLocalCache();
      final safeCache = ConcurrencySafeCache(cache);
      final box = CacheBox<String>(
        cache: safeCache,
        key: 'session',
        encode: (value) => {'value': value},
        decode: (map) => map['value'] as String,
      );

      await box.write('token');
      //2.- Ejecutamos una mutación que decide limpiar la entrada.
      await box.mutate((current, save, clear) async {
        clear();
        return null;
      });

      //3.- Comprobamos que la lectura posterior devuelve null tras la limpieza.
      expect(await box.read(), isNull);
    });
  });
}
