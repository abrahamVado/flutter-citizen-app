abstract class LocalCache {
  Future<void> write(String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> read(String key);
  Future<void> delete(String key);
}

class InMemoryLocalCache implements LocalCache {
  InMemoryLocalCache();

  final Map<String, Map<String, dynamic>> _store = {};

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    //1.- Guardamos el mapa recibido para simular la persistencia de DataStore/Room.
    _store[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    //1.- Devolvemos una copia del registro almacenado evitando mutaciones externas.
    final value = _store[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    //1.- Eliminamos cualquier valor previamente guardado asociando la llave recibida.
    _store.remove(key);
  }
}
