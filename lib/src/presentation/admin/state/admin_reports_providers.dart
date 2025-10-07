import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/paginated_reports.dart';
import '../../../domain/entities/report.dart';

class AdminReportsListState {
  const AdminReportsListState({
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.page,
    this.error,
  });

  const AdminReportsListState.initial()
    : items = const [],
      isLoading = false,
      isLoadingMore = false,
      hasMore = true,
      page = 0,
      error = null;

  //1.- Listado visible actualmente en la tabla de reportes.
  final List<Report> items;
  //2.- Bandera para indicar cuando la primera página está cargándose.
  final bool isLoading;
  //3.- Bandera para indicar si estamos anexando una página adicional.
  final bool isLoadingMore;
  //4.- Indica si podemos solicitar más páginas al backend.
  final bool hasMore;
  //5.- Número de página actual que se ha sincronizado.
  final int page;
  //6.- Almacena el mensaje de error para mostrar retroalimentación en la UI.
  final Object? error;

  AdminReportsListState copyWith({
    List<Report>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Object? error = _noError,
  }) {
    //1.- Generamos estados derivados manteniendo la inmutabilidad del controlador.
    return AdminReportsListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error == _noError ? this.error : error,
    );
  }

  static const _noError = Object();
}

class AdminReportsListController extends StateNotifier<AdminReportsListState> {
  AdminReportsListController(this._ref)
    : super(const AdminReportsListState.initial()) {
    //1.- Disparamos la primera carga en cuanto se crea el controlador.
    loadInitial();
  }

  final Ref _ref;
  static const _pageSize = 10;

  Future<void> loadInitial() async {
    //1.- Evitamos solicitudes redundantes si ya se está cargando la primera página.
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      page: 0,
      hasMore: true,
    );
    try {
      final result = await _ref
          .read(reportsRepositoryProvider)
          .fetchReports(page: 0, pageSize: _pageSize);
      state = state.copyWith(
        items: result.items,
        page: result.page,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    //1.- Solo anexamos más datos cuando existen más páginas disponibles.
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final nextPage = state.page + 1;
      final result = await _ref
          .read(reportsRepositoryProvider)
          .fetchReports(page: nextPage, pageSize: _pageSize);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        page: result.page,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<void> refresh() async {
    //1.- Reutilizamos la carga inicial para refrescar completamente el listado.
    await loadInitial();
  }
}

final adminDashboardMetricsProvider = FutureProvider.autoDispose((ref) async {
  //1.- Pedimos las métricas agregadas cada vez que la vista del dashboard lo requiera.
  return ref.watch(reportsRepositoryProvider).fetchDashboardMetrics();
});

final adminReportsListProvider =
    StateNotifierProvider.autoDispose<
      AdminReportsListController,
      AdminReportsListState
    >((ref) {
      //1.- Exponemos el controlador de paginación para que la UI escuche sus cambios.
      return AdminReportsListController(ref);
    });

final adminReportDetailProvider = FutureProvider.autoDispose
    .family<Report, String>((ref, id) async {
      //1.- Recuperamos el detalle del reporte solicitado antes de renderizar la vista.
      return ref.watch(reportsRepositoryProvider).fetchReportById(id);
    });
