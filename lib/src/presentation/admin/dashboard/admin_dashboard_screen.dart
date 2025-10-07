import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //1.- Simulamos tarjetas resumen que representarán listas, mapas y gráficas.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de actividad', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _DashboardCard(title: 'Reportes pendientes', value: '12'),
              _DashboardCard(title: 'Reportes resueltos', value: '48'),
              _DashboardCard(title: 'Incidentes críticos', value: '3'),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Ver listado completo',
            onPressed: () {
              //1.- Aquí navegaremos hacia la pantalla detallada de reportes administrativos.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navegación al listado en construcción.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    //1.- Representamos una tarjeta con estadísticas principales del panel.
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
