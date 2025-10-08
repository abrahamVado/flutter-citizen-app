import '../entities/auth_credentials.dart';
import '../value_objects/auth_token.dart';
import '../value_objects/social_provider.dart';

abstract class AuthRepository {
  Future<AuthToken> authenticate(AuthCredentials credentials);
  Future<AuthToken> register(AuthCredentials credentials);
  Future<void> recoverPassword(String email);
  Future<AuthToken> signInWithProvider(SocialProvider provider);
}
