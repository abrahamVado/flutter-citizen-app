import 'package:citizen_reports_flutter/src/domain/usecases/recover_password.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'package:citizen_reports_flutter/src/presentation/public/auth/recover_password_controller.dart';
import 'package:citizen_reports_flutter/src/presentation/public/auth/recover_password_state.dart';

void main() {
  group('RecoverPasswordController', () {
    test('emits success state when email is sent', () async {
      //1.- Preparamos el repositorio para registrar el correo procesado.
      final repository = FakeAuthRepository();
      final controller = RecoverPasswordController(
        recoverPassword: RecoverPassword(authRepository: repository),
      );

      controller.updateEmail('user@example.com');
      await controller.submit();

      expect(repository.lastRecoveredEmail, 'user@example.com');
      expect(controller.state.status, RecoverPasswordStatus.success);
      expect(controller.state.errorMessage, isNull);
    });

    test('emits error state when repository throws', () async {
      //1.- Configuramos el repositorio para lanzar un fallo controlado.
      final repository = FakeAuthRepository()..recoverError = Exception('offline');
      final controller = RecoverPasswordController(
        recoverPassword: RecoverPassword(authRepository: repository),
      );

      controller.updateEmail('user@example.com');
      await controller.submit();

      expect(controller.state.status, RecoverPasswordStatus.error);
      expect(controller.state.errorMessage, contains('offline'));
    });
  });
}
