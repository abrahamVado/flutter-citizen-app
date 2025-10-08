import 'package:citizen_reports_flutter/src/domain/entities/auth_credentials.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/auth_repository.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/auth_token.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/social_provider.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository();

  AuthToken authenticateReturn = AuthToken(
    'auth-token',
    expiresAt: DateTime.now().add(const Duration(hours: 8)),
  );
  AuthToken? registerReturn;
  AuthToken? providerReturn;
  Exception? registerError;
  Exception? providerError;
  Exception? recoverError;
  String? lastRecoveredEmail;
  SocialProvider? lastProvider;

  @override
  Future<AuthToken> authenticate(AuthCredentials credentials) async {
    //1.- Retornamos un token por defecto para permitir instanciar el SessionController durante las pruebas.
    return authenticateReturn;
  }

  @override
  Future<AuthToken> register(AuthCredentials credentials) async {
    //1.- Simulamos tanto rutas exitosas como fallidas según la configuración del test.
    if (registerError != null) {
      throw registerError!;
    }
    return registerReturn ?? authenticateReturn;
  }

  @override
  Future<void> recoverPassword(String email) async {
    //1.- Guardamos el correo para poder aseverar que se llamó al repositorio.
    lastRecoveredEmail = email;
    if (recoverError != null) {
      throw recoverError!;
    }
  }

  @override
  Future<AuthToken> signInWithProvider(SocialProvider provider) async {
    //1.- Permitimos que la prueba fuerce tanto éxitos como errores controlados.
    lastProvider = provider;
    if (providerError != null) {
      throw providerError!;
    }
    return providerReturn ?? authenticateReturn;
  }
}
