import '../repositories/auth_repository.dart';
import '../value_objects/auth_token.dart';
import '../value_objects/social_provider.dart';

class SignInWithProvider {
  const SignInWithProvider({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<AuthToken> call(SocialProvider provider) {
    //1.- Delegamos al repositorio la autenticación social para obtener un token interno.
    return _authRepository.signInWithProvider(provider);
  }
}
