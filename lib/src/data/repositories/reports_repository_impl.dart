import '../../domain/entities/folio_status.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/reports_repository.dart';
import '../cache/local_cache.dart';
import '../datasources/api_client.dart';
import '../models/mappers.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({required ApiClient apiClient, required LocalCache cache})
      : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final LocalCache _cache;

  static const _folioHistoryKey = 'folio_history';

  @override
  Future<Report> submitReport(ReportRequest request) async {
    //1.- Serializamos la petición y la enviamos al API para generar el folio.
    final map = ReportRequestMapper.toMap(request);
    final report = await _apiClient.submitReport(map);
    //2.- Actualizamos la caché de historial con el nuevo folio confirmado.
    final history = await _cache.read(_folioHistoryKey) ?? {'items': <Map<String, dynamic>>[]};
    final items = List<Map<String, dynamic>>.from(history['items'] as List<dynamic>);
    items.insert(0, {
      'folio': report.id,
      'status': report.status,
      'createdAt': report.createdAt.toIso8601String(),
    });
    await _cache.write(_folioHistoryKey, {'items': items});
    return report;
  }

  @override
  Future<FolioStatus> lookupFolio(String folio) async {
    //1.- Intentamos responder con datos cacheados para mostrar resultados inmediatos.
    final history = await _cache.read(_folioHistoryKey);
    FolioStatus? cachedStatus;
    if (history != null) {
      final items = List<Map<String, dynamic>>.from(history['items'] as List<dynamic>);
      final cached = items.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['folio'] == folio,
            orElse: () => null,
          );
      if (cached != null) {
        //2.- Construimos un FolioStatus parcial en lo que llega la respuesta remota.
        cachedStatus = FolioStatus(
          folio: cached['folio'] as String,
          status: cached['status'] as String,
          lastUpdate: DateTime.parse(cached['createdAt'] as String),
          history: const ['Consulta offline'],
        );
      }
    }
    try {
      //3.- Consultamos al API para obtener el detalle actualizado.
      return await _apiClient.lookupFolio(folio);
    } catch (_) {
      //4.- Si ocurre un error remoto, recuperamos el estado cacheado como respaldo offline.
      if (cachedStatus != null) {
        return cachedStatus;
      }
      rethrow;
    }
  }
}
