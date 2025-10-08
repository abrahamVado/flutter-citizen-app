import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_citizen_app/src/presentation/design/shadcn/components/shadcn_button.dart';

void main() {
  testWidgets('ShadcnButton triggers callback when tapped', (tester) async {
    //1.- Montamos el botón dentro de un MaterialApp para disponer de temas y navegación.
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShadcnButton(
            label: 'Presionar',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    //2.- Simulamos el tap sobre el botón para verificar que el callback se ejecute.
    await tester.tap(find.text('Presionar'));
    expect(tapped, isTrue);
  });

  testWidgets('ShadcnButton shows progress indicator when loading', (tester) async {
    //1.- Renderizamos el botón con la propiedad loading y un callback que no debe dispararse.
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShadcnButton(
            label: 'Procesando',
            loading: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    //2.- Confirmamos que se muestra el indicador circular y que la acción no se ejecute.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Procesando'));
    expect(tapped, isFalse);
  });
}
