import '../../domain/entities/auth_credentials.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/auth_token.dart';
import '../cache/local_cache.dart';
import '../datasources/api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required ApiClient apiClient, required LocalCache cache})
      : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final LocalCache _cache;

  static const _tokenKey = 'auth_token';

  @override
  Future<AuthToken> authenticate(AuthCredentials credentials) async {
    //1.- Consumimos el cliente para obtener el token remoto.
    final token = await _apiClient.authenticate(
      email: credentials.email,
      password: credentials.password,
    );
    //2.- Guardamos el token serializado para reutilizarlo en lanzamientos futuros.
    await _cache.write(_tokenKey, {
      'value': token.value,
      'expiresAt': token.expiresAt.toIso8601String(),
    });
    //3.- Devolvemos el token a la capa de dominio.
    return token;
  }

  Future<AuthToken?> restoreSession() async {
    //1.- Intentamos leer el token almacenado para restaurar sesiones previas.
    final data = await _cache.read(_tokenKey);
    if (data == null) {
      return null;
    }
    //2.- Reconstruimos el objeto y validamos su vigencia.
    final token = AuthToken(
      data['value'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
    );
    //3.- Si está expirado lo eliminamos para forzar un nuevo inicio de sesión.
    if (token.isExpired) {
      await _cache.delete(_tokenKey);
      return null;
    }
    return token;
  }
}
