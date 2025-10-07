import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/entities/folio_status.dart';
import '../../domain/entities/paginated_reports.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reports_repository.dart';
import '../cache/local_cache.dart';
import '../datasources/api_client.dart';
import '../models/mappers.dart';
import '../../utils/cache/cache_box.dart';
import '../../utils/cache/concurrency_safe_cache.dart';
import '../../utils/network/network_executor.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({
    required ApiClient apiClient,
    required LocalCache cache,
  }) : _apiClient = apiClient,
       _folioHistoryBox = CacheBox<List<Map<String, dynamic>>>(
         cache: ConcurrencySafeCache(cache),
         key: _folioHistoryKey,
         encode: _encodeHistory,
         decode: _decodeHistory,
       ),
       _executor = NetworkExecutor();

  final ApiClient _apiClient;
  final CacheBox<List<Map<String, dynamic>>> _folioHistoryBox;
  final NetworkExecutor _executor;

  static const _folioHistoryKey = 'folio_history';

  static Map<String, dynamic> _encodeHistory(List<Map<String, dynamic>> items) {
    //1.- Serializamos la colección completa para mantener el historial en caché.
    return {'items': items};
  }

  static List<Map<String, dynamic>> _decodeHistory(Map<String, dynamic> map) {
    //1.- Convertimos el mapa almacenado en una lista mutable para posteriores mutaciones.
    return List<Map<String, dynamic>>.from(map['items'] as List<dynamic>);
  }

  static FolioStatus? _restoreCachedStatus(
    String folio,
    List<Map<String, dynamic>> items,
  ) {
    //1.- Buscamos si el folio solicitado se encuentra en la colección cacheada.
    final match = items.firstWhere(
      (entry) => entry['folio'] == folio,
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty) {
      return null;
    }
    //2.- Construimos una respuesta mínima para mostrar al usuario mientras no haya red.
    return FolioStatus(
      folio: match['folio'] as String,
      status: match['status'] as String,
      lastUpdate: DateTime.parse(match['createdAt'] as String),
      history: const ['Consulta offline'],
    );
  }

  @override
  Future<AdminDashboardMetrics> fetchDashboardMetrics() {
    //1.- Delegamos al cliente HTTP para obtener estadísticas globales del panel.
    return _apiClient.fetchAdminDashboardMetrics();
  }

  @override
  Future<PaginatedReports> fetchReports({
    required int page,
    required int pageSize,
  }) {
    //1.- Pedimos al backend una página específica de reportes administrativos.
    return _apiClient.fetchReportsPage(page: page, pageSize: pageSize);
  }

  @override
  Future<Report> fetchReportById(String id) {
    //1.- Recuperamos un reporte puntual para mostrar su detalle en el panel.
    return _apiClient.fetchReportDetail(id);
  }

  @override
  Future<Report> updateReportStatus({
    required String id,
    required String status,
  }) {
    //1.- Propagamos la actualización de estado hacia el backend simulado.
    return _apiClient.updateReportStatus(id: id, status: status);
  }

  @override
  Future<void> deleteReport(String id) {
    //1.- Solicitamos eliminar el reporte del origen de datos remoto.
    return _apiClient.deleteReport(id);
  }

  @override
  Future<Report> submitReport(ReportRequest request) async {
    //1.- Serializamos la petición y la enviamos al API para generar el folio.
    final map = ReportRequestMapper.toMap(request);
    final report = await _apiClient.submitReport(map);
    //2.- Actualizamos la caché de historial utilizando una mutación atómica.
    await _folioHistoryBox.mutate((current, save, clear) async {
      final items = List<Map<String, dynamic>>.from(
        current ?? const <Map<String, dynamic>>[],
      );
      items.insert(0, {
        'folio': report.id,
        'status': report.status,
        'createdAt': report.createdAt.toIso8601String(),
      });
      save(items);
      return null;
    });
    //3.- Regresamos el reporte recién confirmado.
    return report;
  }

  @override
  Future<FolioStatus> lookupFolio(String folio) async {
    //1.- Recuperamos el historial cacheado para preparar un posible respaldo offline.
    final cachedItems = await _folioHistoryBox.read();
    final cachedStatus = cachedItems == null
        ? null
        : _restoreCachedStatus(folio, cachedItems);
    //2.- Ejecutamos la consulta remota aplicando fallback si existe información local.
    return _executor.runWithFallback(
      () => _apiClient.lookupFolio(folio),
      fallback: cachedStatus == null ? null : (_) => cachedStatus,
    );
  }
}
