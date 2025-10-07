import '../../data/cache/local_cache.dart';
import 'concurrency_safe_cache.dart';

typedef CacheEncoder<T> = Map<String, dynamic> Function(T value);
typedef CacheDecoder<T> = T Function(Map<String, dynamic> map);
typedef CacheMutation<T, R> =
    Future<R> Function(
      T? current,
      void Function(T value) save,
      void Function() clear,
    );

/// Provee operaciones tipadas sobre una entrada de caché específica.
class CacheBox<T> {
  CacheBox({
    required ConcurrencySafeCache cache,
    required String key,
    required CacheEncoder<T> encode,
    required CacheDecoder<T> decode,
  }) : _cache = cache,
       _key = key,
       _encode = encode,
       _decode = decode;

  final ConcurrencySafeCache _cache;
  final String _key;
  final CacheEncoder<T> _encode;
  final CacheDecoder<T> _decode;

  Future<T?> read() {
    //1.- Ejecutamos la lectura bajo el candado y devolvemos el valor tipado.
    return _cache.runGuarded((delegate) async {
      final raw = await delegate.read(_key);
      if (raw == null) {
        return null;
      }
      return _decode(raw);
    });
  }

  Future<void> write(T value) {
    //1.- Serializamos y escribimos el valor dentro del candado secuencial.
    return _cache.runGuarded((delegate) async {
      await delegate.write(_key, _encode(value));
    });
  }

  Future<void> delete() {
    //1.- Eliminamos la entrada bajo el mismo candado compartido.
    return _cache.runGuarded((delegate) => delegate.delete(_key));
  }

  Future<R> mutate<R>(CacheMutation<T, R> mutation) {
    //1.- Ejecutamos lectura y escritura en un solo bloque para mantener atomicidad.
    return _cache.runGuarded((delegate) async {
      final raw = await delegate.read(_key);
      final current = raw == null ? null : _decode(raw);
      var shouldWrite = false;
      var shouldDelete = false;
      T? nextValue;
      void save(T value) {
        //2.- Marcamos que se debe persistir el nuevo valor.
        shouldWrite = true;
        shouldDelete = false;
        nextValue = value;
      }

      void clear() {
        //3.- Indicamos que debe limpiarse la entrada al finalizar.
        shouldWrite = false;
        shouldDelete = true;
        nextValue = null;
      }

      final result = await mutation(current, save, clear);

      if (shouldWrite && nextValue != null) {
        //4.- Guardamos el valor calculado utilizando el encoder proporcionado.
        await delegate.write(_key, _encode(nextValue as T));
      } else if (shouldDelete) {
        //5.- Eliminamos la entrada cuando la mutación así lo solicitó.
        await delegate.delete(_key);
      }

      return result;
    });
  }
}
