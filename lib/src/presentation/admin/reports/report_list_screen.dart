import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/shadcn/components/shadcn_button.dart';
import '../../design/shadcn/components/shadcn_card.dart';
import '../state/admin_reports_providers.dart';

class ReportListScreen extends ConsumerWidget {
  const ReportListScreen({super.key, required this.onReportSelected});

  final void Function(String reportId) onReportSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //1.- Observamos el estado del listado paginado para renderizarlo dinámicamente.
    final state = ref.watch(adminReportsListProvider);
    final controller = ref.read(adminReportsListProvider.notifier);

    Future<void> handleRefresh() async {
      //1.- Solicitamos recargar la información desde la primera página.
      await controller.refresh();
      ref.invalidate(adminDashboardMetricsProvider);
    }

    final items = <Widget>[];
    if (state.isLoading) {
      items.add(const LinearProgressIndicator());
    }
    if (state.error != null) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ShadcnCard(
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No fue posible cargar los reportes: ${state.error}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => controller.loadInitial(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (state.items.isEmpty && !state.isLoading) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('No hay reportes disponibles por el momento.'),
          ),
        ),
      );
    } else {
      for (final report in state.items) {
        items.add(
          ShadcnCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folio ${report.id}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Estado: ${report.status}\nCreado: ${report.createdAt.toLocal()}'
                      .split('.')
                      .first,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ShadcnButton(
                    label: 'Ver detalle',
                    expand: false,
                    onPressed: () => onReportSelected(report.id),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (state.isLoadingMore) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (state.hasMore) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ShadcnButton(
            label: 'Cargar más',
            onPressed: () => controller.loadMore(),
          ),
        ),
      );
    }

    final displayItems = items.isEmpty ? const [SizedBox(height: 200)] : items;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: handleRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            //1.- Detectamos cuando llegamos al final del scroll para pedir más datos.
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200 &&
                !state.isLoadingMore &&
                state.hasMore) {
              controller.loadMore();
            }
            return false;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) => displayItems[index],
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: displayItems.length,
          ),
        ),
      ),
    );
  }
}
