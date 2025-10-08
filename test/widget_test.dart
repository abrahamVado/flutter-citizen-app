import 'package:citizen_reports_flutter/src/app/citizen_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CitizenApp arranca mostrando accesos ciudadanos clave', (tester) async {
    await tester.pumpWidget(const CitizenApp());

    //1.- Verificamos que la experiencia predeterminada expone las llamadas a la acción públicas.
    expect(find.text('Comenzar reporte'), findsOneWidget);
    expect(find.text('Consultar'), findsOneWidget);
  });
}
