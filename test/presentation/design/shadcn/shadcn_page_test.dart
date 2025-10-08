import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_citizen_app/src/presentation/design/shadcn/components/shadcn_page.dart';

void main() {
  testWidgets('ShadcnPage renders title and child content', (tester) async {
    //1.- Ensamblamos la página con un contenido sencillo para comprobar el layout base.
    await tester.pumpWidget(
      const MaterialApp(
        home: ShadcnPage(
          title: 'Panel',
          child: Text('Contenido principal'),
        ),
      ),
    );

    //2.- Confirmamos que el AppBar muestre el título y que el cuerpo contenga el widget hijo.
    expect(find.text('Panel'), findsOneWidget);
    expect(find.text('Contenido principal'), findsOneWidget);
  });

  testWidgets('ShadcnPage enables scrolling when requested', (tester) async {
    //1.- Inyectamos múltiples elementos para verificar que el flag scrollable envuelva el contenido.
    await tester.pumpWidget(
      MaterialApp(
        home: ShadcnPage(
          title: 'Lista',
          scrollable: true,
          child: Column(
            children: List.generate(
              30,
              (index) => Text('Elemento $index'),
            ),
          ),
        ),
      ),
    );

    //2.- Realizamos un drag para asegurar que se pueda desplazar el contenido.
    final gesture = await tester.startGesture(const Offset(200, 500));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(find.text('Elemento 0'), findsOneWidget);
  });
}
