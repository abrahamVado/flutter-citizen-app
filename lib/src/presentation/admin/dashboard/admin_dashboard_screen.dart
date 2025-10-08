import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/shadcn/components/shadcn_button.dart';
import '../../design/shadcn/components/shadcn_card.dart';
import '../state/admin_navigation_controller.dart';
import '../state/admin_reports_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Leemos las métricas del panel y reaccionamos a sus estados de carga.
    final metrics = ref.watch(adminDashboardMetricsProvider);
    final navigator = ref.read(adminNavigationProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de actividad',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          metrics.when(
            data: (data) {
              //1.- Renderizamos tarjetas con los valores obtenidos en tiempo real.
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _DashboardCard(
                    title: 'Reportes pendientes',
                    value: data.pendingReports.toString(),
                  ),
                  _DashboardCard(
                    title: 'Reportes resueltos',
                    value: data.resolvedReports.toString(),
                  ),
                  _DashboardCard(
                    title: 'Incidentes críticos',
                    value: data.criticalIncidents.toString(),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              //1.- Mostramos retroalimentación en caso de que la consulta falle.
              return ShadcnCard(
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('No se pudieron cargar las métricas: $error'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.invalidate(adminDashboardMetricsProvider),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          ShadcnButton(
            label: 'Ver listado completo',
            onPressed: () {
              //1.- Navegamos al listado de reportes usando el controlador global.
              navigator.goToReports();
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
    return SizedBox(
      width: 220,
      child: ShadcnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
