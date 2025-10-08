import 'package:flutter/material.dart';

import '../../design/shadcn/components/shadcn_button.dart';
import '../../design/shadcn/components/shadcn_card.dart';
import '../../design/shadcn/components/shadcn_page.dart';

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //1.- Construimos la pantalla inicial con accesos rápidos a los flujos ciudadanos.
    return ShadcnPage(
      title: 'Ciudadanía Activa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reporta y da seguimiento a incidencias en tu comunidad.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 320,
                child: ShadcnCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.report_gmailerrorred,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Reportar incidencia',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Indica la ubicación y describe el incidente para que el equipo pueda atenderlo.',
                      ),
                      const SizedBox(height: 16),
                      ShadcnButton(
                        label: 'Comenzar reporte',
                        icon: Icons.navigation_outlined,
                        onPressed: () => Navigator.of(context).pushNamed('/map'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: ShadcnCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.search_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Consultar folio',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresa tu folio para conocer el estado y seguimiento más reciente.',
                      ),
                      const SizedBox(height: 16),
                      ShadcnButton(
                        label: 'Consultar',
                        icon: Icons.open_in_new,
                        onPressed: () => Navigator.of(context).pushNamed('/folio'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ShadcnButton(
            label: 'Ingresar como administrador',
            variant: ShadcnButtonVariant.ghost,
            expand: false,
            onPressed: () {
              //1.- Navegamos a la nueva pantalla de autenticación administrada por Riverpod.
              Navigator.of(context).pushNamed('/auth');
            },
          ),
        ],
      ),
    );
  }
}
