import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../widgets/primary_button.dart';
import '../state/admin_navigation_controller.dart';
import '../state/admin_reports_providers.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  String? _selectedStatus;
  bool _isUpdating = false;
  bool _isDeleting = false;

  static const _statusOptions = [
    'en_revision',
    'en_proceso',
    'resuelto',
    'critico',
  ];

  @override
  Widget build(BuildContext context) {
    //1.- Consultamos el detalle del reporte con el identificador proporcionado.
    final reportAsync = ref.watch(adminReportDetailProvider(widget.reportId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: reportAsync.when(
          data: (report) {
            _selectedStatus ??= report.status;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle ${widget.reportId}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tipo: ${report.incidentType.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Descripción: ${report.description}'),
                  const SizedBox(height: 8),
                  Text(
                    'Coordenadas: ${report.latitude.toStringAsFixed(4)}, '
                    '${report.longitude.toStringAsFixed(4)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Creado: ${report.createdAt.toLocal()}'.split('.').first,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    items: _statusOptions
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: _isUpdating
                        ? null
                        : (value) {
                            //1.- Permitimos seleccionar el nuevo estado del reporte.
                            setState(() {
                              _selectedStatus = value;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Estado del reporte',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: _isUpdating
                              ? 'Actualizando...'
                              : 'Actualizar estado',
                          onPressed: _isUpdating || _selectedStatus == null
                              ? null
                              : () async {
                                  //1.- Propagamos el nuevo estado al repositorio y refrescamos vistas dependientes.
                                  setState(() => _isUpdating = true);
                                  try {
                                    await ref
                                        .read(reportsRepositoryProvider)
                                        .updateReportStatus(
                                          id: report.id,
                                          status: _selectedStatus!,
                                        );
                                    ref.invalidate(
                                      adminReportDetailProvider(report.id),
                                    );
                                    ref.invalidate(adminReportsListProvider);
                                    ref.invalidate(
                                      adminDashboardMetricsProvider,
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Estado actualizado correctamente.',
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo actualizar: $error',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isUpdating = false);
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PrimaryButton(
                          label: _isDeleting
                              ? 'Eliminando...'
                              : 'Eliminar reporte',
                          onPressed: _isDeleting
                              ? null
                              : () async {
                                  //1.- Eliminamos el reporte y regresamos al listado principal.
                                  setState(() => _isDeleting = true);
                                  try {
                                    await ref
                                        .read(reportsRepositoryProvider)
                                        .deleteReport(report.id);
                                    ref.invalidate(adminReportsListProvider);
                                    ref.invalidate(
                                      adminDashboardMetricsProvider,
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Reporte eliminado.'),
                                      ),
                                    );
                                    ref
                                        .read(adminNavigationProvider.notifier)
                                        .goToReports();
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo eliminar: $error',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isDeleting = false);
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No se pudo cargar el reporte: $error'),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Reintentar',
                onPressed: () {
                  //1.- Reintentamos la carga del detalle al invalidar el provider asociado.
                  ref.invalidate(adminReportDetailProvider(widget.reportId));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
