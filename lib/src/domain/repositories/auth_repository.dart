import '../entities/auth_credentials.dart';
import '../value_objects/auth_token.dart';

abstract class AuthRepository {
  Future<AuthToken> authenticate(AuthCredentials credentials);
}
