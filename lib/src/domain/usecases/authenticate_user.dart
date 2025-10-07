import '../entities/auth_credentials.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/auth_token.dart';

class AuthenticateUser {
  const AuthenticateUser({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<AuthToken> call(AuthCredentials credentials) {
    //1.- Delegamos la autenticación al repositorio asegurando un único punto de entrada.
    return _authRepository.authenticate(credentials);
  }
}
