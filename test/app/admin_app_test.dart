import 'package:citizen_reports_flutter/src/app/admin_app.dart';
import 'package:citizen_reports_flutter/src/app/providers.dart';
import 'package:citizen_reports_flutter/src/app/state/session_controller.dart';
import 'package:citizen_reports_flutter/src/domain/entities/auth_credentials.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/auth_repository.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/authenticate_user.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/auth_token.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthToken> authenticate(AuthCredentials credentials) async {
    //1.- Entregamos un token prefabricado para simular respuestas exitosas del backend.
    return AuthToken('token', expiresAt: DateTime(2030));
  }
}

SessionController _buildSessionController({required bool authenticated}) {
  //1.- Creamos el controlador usando el caso de uso real pero respaldado por el repositorio falso.
  final controller = SessionController(
    authenticateUser: AuthenticateUser(authRepository: _FakeAuthRepository()),
  );
  if (authenticated) {
    //2.- Publicamos un token anticipadamente para iniciar la app en modo autenticado.
    controller.markAuthenticated(AuthToken('token', expiresAt: DateTime(2030)));
  }
  return controller;
}

void main() {
  testWidgets('AdminApp exige autenticación antes de mostrar rutas privadas', (tester) async {
    //1.- Montamos la aplicación con la sesión firmada fuera para observar la pantalla de acceso.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          sessionControllerProvider.overrideWith((ref) => _buildSessionController(authenticated: false)),
        ],
        child: const AdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    //2.- Confirmamos que se muestra la interfaz de autenticación y no el panel administrativo.
    expect(find.text('Acceso administrativo'), findsOneWidget);
    expect(find.text('Panel administrativo'), findsNothing);
  });

  testWidgets('AdminApp muestra el shell administrativo cuando la sesión está autenticada', (tester) async {
    //1.- Inyectamos un controlador que ya marcó la sesión como autenticada para saltar la pantalla de login.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          sessionControllerProvider.overrideWith((ref) => _buildSessionController(authenticated: true)),
        ],
        child: const AdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    //2.- Verificamos que el panel administrativo sea visible inmediatamente.
    expect(find.text('Panel administrativo'), findsOneWidget);
  });
}
