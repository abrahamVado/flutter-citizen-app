import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //1.- Construimos la pantalla inicial con accesos rápidos a los flujos ciudadanos.
    return Scaffold(
      appBar: AppBar(title: const Text('Ciudadanía Activa')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporta y da seguimiento a incidencias en tu comunidad.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Reportar incidencia',
              icon: Icons.report,
              onPressed: () => Navigator.of(context).pushNamed('/map'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Consultar folio',
              icon: Icons.search,
              onPressed: () => Navigator.of(context).pushNamed('/folio'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                //1.- Navegamos a la nueva pantalla de autenticación administrada por Riverpod.
                Navigator.of(context).pushNamed('/auth');
              },
              child: const Text('Ingresar como administrador'),
            ),
          ],
        ),
      ),
    );
  }
}
