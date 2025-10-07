import 'dart:async';

import '../../data/cache/local_cache.dart';

/// Envuelve un [LocalCache] garantizando operaciones secuenciales.
class ConcurrencySafeCache implements LocalCache {
  ConcurrencySafeCache(this._delegate);

  final LocalCache _delegate;
  Future<void> _queue = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() task) {
    //1.- Creamos un `Completer` para devolver el resultado al consumidor original.
    final completer = Completer<T>();
    //2.- Encadenamos la tarea al `queue` para asegurar que se ejecute tras las previas.
    _queue = _queue.then((_) async {
      try {
        //3.- Ejecutamos la acción solicitada propagando el resultado exitoso.
        final result = await task();
        completer.complete(result);
      } catch (error, stackTrace) {
        //4.- Propagamos cualquier error manteniendo el `StackTrace` original.
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// Permite ejecutar bloques completos contra el delegate bajo el candado secuencial.
  Future<T> runGuarded<T>(Future<T> Function(LocalCache delegate) task) {
    //1.- Encapsulamos el acceso al delegate evitando exponerlo directamente.
    return _enqueue(() => task(_delegate));
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) {
    //1.- Serializamos la escritura a través de la cola interna.
    return _enqueue(() => _delegate.write(key, value));
  }

  @override
  Future<Map<String, dynamic>?> read(String key) {
    //1.- Serializamos la lectura para evitar condiciones de carrera con escrituras.
    return _enqueue(() => _delegate.read(key));
  }

  @override
  Future<void> delete(String key) {
    //1.- Serializamos la eliminación para mantener la coherencia de la caché.
    return _enqueue(() => _delegate.delete(key));
  }
}
