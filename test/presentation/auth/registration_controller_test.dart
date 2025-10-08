import 'package:citizen_reports_flutter/src/app/state/session_controller.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/authenticate_user.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/register_user.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/auth_token.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'package:citizen_reports_flutter/src/presentation/public/auth/registration_controller.dart';
import 'package:citizen_reports_flutter/src/presentation/public/auth/registration_state.dart';

void main() {
  group('RegistrationController', () {
    test('marks session as authenticated on successful registration', () async {
      //1.- Configuramos el repositorio falso para devolver un token válido durante el registro.
      final repository = FakeAuthRepository()
        ..registerReturn = AuthToken('reg', expiresAt: DateTime.now().add(const Duration(hours: 1)));
      final sessionController = SessionController(
        authenticateUser: AuthenticateUser(authRepository: repository),
      );
      final controller = RegistrationController(
        registerUser: RegisterUser(authRepository: repository),
        sessionController: sessionController,
      );

      controller.updateEmail('admin@example.com');
      controller.updatePassword('secret');

      await controller.submit();

      expect(controller.state.status, RegistrationStatus.success);
      expect(sessionController.state.status, SessionStatus.authenticated);
      expect(sessionController.state.token?.value, 'reg');
    });

    test('emits error state when repository fails', () async {
      //1.- Inyectamos una excepción para validar que el controlador la propaga correctamente.
      final repository = FakeAuthRepository()
        ..registerError = Exception('network');
      final sessionController = SessionController(
        authenticateUser: AuthenticateUser(authRepository: repository),
      );
      final controller = RegistrationController(
        registerUser: RegisterUser(authRepository: repository),
        sessionController: sessionController,
      );

      controller.updateEmail('admin@example.com');
      controller.updatePassword('secret');

      await controller.submit();

      expect(controller.state.status, RegistrationStatus.error);
      expect(controller.state.errorMessage, contains('network'));
      expect(sessionController.state.status, SessionStatus.signedOut);
    });
  });
}
