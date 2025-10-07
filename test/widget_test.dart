import 'package:citizen_reports_flutter/src/app/citizen_reports_app.dart';
import 'package:citizen_reports_flutter/src/app/providers.dart';
import 'package:citizen_reports_flutter/src/domain/entities/auth_credentials.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/auth_repository.dart';
import 'package:citizen_reports_flutter/src/domain/value_objects/auth_token.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthToken> authenticate(AuthCredentials credentials) async {
    //1.- Generamos un token fijo para simular autenticaciones exitosas.
    return AuthToken('token', expiresAt: DateTime.now().add(const Duration(hours: 1)));
  }
}

void main() {
  testWidgets('muestra acciones principales en la pantalla ciudadana', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const CitizenReportsApp(),
      ),
    );

    //1.- Buscamos los botones principales que replican la pantalla web.
    expect(find.text('Reportar incidencia'), findsOneWidget);
    expect(find.text('Consultar folio'), findsOneWidget);
  });
}
