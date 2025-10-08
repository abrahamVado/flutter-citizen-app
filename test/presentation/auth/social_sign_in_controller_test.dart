import 'package:citizen_reports_flutter/src/app/state/session_controller.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/authenticate_user.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/sign_in_with_provider.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/auth_token.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/social_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'package:citizen_reports_flutter/src/presentation/public/auth/social_sign_in_controller.dart';
import 'package:citizen_reports_flutter/src/presentation/public/auth/social_sign_in_state.dart';

void main() {
  group('SocialSignInController', () {
    test('propagates token to session on success', () async {
      //1.- Preparamos el repositorio para devolver un token social exitoso.
      final repository = FakeAuthRepository()
        ..providerReturn = AuthToken('social', expiresAt: DateTime.now().add(const Duration(hours: 1)));
      final sessionController = SessionController(
        authenticateUser: AuthenticateUser(authRepository: repository),
      );
      final controller = SocialSignInController(
        signInWithProvider: SignInWithProvider(authRepository: repository),
        sessionController: sessionController,
      );

      await controller.signIn(SocialProvider.google);

      expect(controller.state.status, SocialSignInStatus.success);
      expect(controller.state.lastProvider, SocialProvider.google);
      expect(sessionController.state.status, SessionStatus.authenticated);
      expect(sessionController.state.token?.value, 'social');
    });

    test('exposes error when sign-in fails', () async {
      //1.- Forzamos un error desde el repositorio social.
      final repository = FakeAuthRepository()
        ..providerError = Exception('rejected');
      final sessionController = SessionController(
        authenticateUser: AuthenticateUser(authRepository: repository),
      );
      final controller = SocialSignInController(
        signInWithProvider: SignInWithProvider(authRepository: repository),
        sessionController: sessionController,
      );

      await controller.signIn(SocialProvider.apple);

      expect(controller.state.status, SocialSignInStatus.error);
      expect(controller.state.errorMessage, contains('rejected'));
      expect(controller.state.lastProvider, SocialProvider.apple);
      expect(sessionController.state.status, SessionStatus.signedOut);
    });
  });
}
