import '../repositories/auth_repository.dart';

class RecoverPassword {
  const RecoverPassword({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<void> call(String email) {
    //1.- Solicitamos al repositorio enviar las instrucciones de restablecimiento.
    return _authRepository.recoverPassword(email);
  }
}
