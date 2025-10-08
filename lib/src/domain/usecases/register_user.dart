import '../entities/auth_credentials.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/auth_token.dart';

class RegisterUser {
  const RegisterUser({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<AuthToken> call(AuthCredentials credentials) {
    //1.- Delegamos el registro al repositorio para mantener la lógica de dominio centralizada.
    return _authRepository.register(credentials);
  }
}
