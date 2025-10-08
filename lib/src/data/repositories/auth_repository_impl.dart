import '../../domain/entities/auth_credentials.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/auth_token.dart';
import '../../domain/value_objects/social_provider.dart';
import '../cache/local_cache.dart';
import '../datasources/api_client.dart';
import '../../utils/cache/cache_box.dart';
import '../../utils/cache/concurrency_safe_cache.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required ApiClient apiClient, required LocalCache cache})
    : _apiClient = apiClient,
      _tokenBox = CacheBox<AuthToken>(
        cache: ConcurrencySafeCache(cache),
        key: _tokenKey,
        encode: _encodeToken,
        decode: _decodeToken,
      );

  final ApiClient _apiClient;
  final CacheBox<AuthToken> _tokenBox;

  static const _tokenKey = 'auth_token';

  static Map<String, dynamic> _encodeToken(AuthToken token) {
    //1.- Serializamos las propiedades clave para almacenarlas en caché.
    return {
      'value': token.value,
      'expiresAt': token.expiresAt.toIso8601String(),
    };
  }

  static AuthToken _decodeToken(Map<String, dynamic> map) {
    //1.- Reconstruimos el objeto de dominio tomando en cuenta su vigencia.
    return AuthToken(
      map['value'] as String,
      expiresAt: DateTime.parse(map['expiresAt'] as String),
    );
  }

  @override
  Future<AuthToken> authenticate(AuthCredentials credentials) async {
    //1.- Consumimos el cliente para obtener el token remoto mediante la política resiliente.
    final token = await _apiClient.authenticate(
      email: credentials.email,
      password: credentials.password,
    );
    //2.- Guardamos el token serializado utilizando el `CacheBox` tipado.
    await _tokenBox.write(token);
    //3.- Devolvemos el token a la capa de dominio.
    return token;
  }

  @override
  Future<AuthToken> register(AuthCredentials credentials) async {
    //1.- Ejecutamos el registro remoto solicitando que el backend cree la cuenta y retorne un token.
    final token = await _apiClient.register(
      email: credentials.email,
      password: credentials.password,
    );
    //2.- Persistimos el token recién emitido para mantener la sesión del nuevo usuario.
    await _tokenBox.write(token);
    //3.- Entregamos el token a la aplicación para redirigir al área administrativa.
    return token;
  }

  @override
  Future<void> recoverPassword(String email) {
    //1.- Delegamos al cliente HTTP el envío del correo de restablecimiento.
    return _apiClient.recoverPassword(email: email);
  }

  @override
  Future<AuthToken> signInWithProvider(SocialProvider provider) async {
    //1.- Solicitamos al backend validar el token social y emitir uno propio de la plataforma.
    final token = await _apiClient.signInWithProvider(provider: provider);
    //2.- Persistimos el token para reutilizarlo en la siguiente sesión.
    await _tokenBox.write(token);
    //3.- Devolvemos el token autenticado a la capa de presentación.
    return token;
  }

  Future<AuthToken?> restoreSession() async {
    //1.- Intentamos leer el token almacenado con el helper seguro para evitar condiciones de carrera.
    final token = await _tokenBox.read();
    if (token == null) {
      return null;
    }
    //2.- Validamos la vigencia del token y eliminamos la entrada si está expirada.
    if (token.isExpired) {
      await _tokenBox.delete();
      return null;
    }
    //3.- Retornamos el token válido listo para usarse en la aplicación.
    return token;
  }
}
