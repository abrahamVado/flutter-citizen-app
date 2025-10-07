import '../../domain/entities/incident_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../cache/local_cache.dart';
import '../datasources/api_client.dart';
import '../models/mappers.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({required ApiClient apiClient, required LocalCache cache})
      : _apiClient = apiClient,
        _cache = cache;

  final ApiClient _apiClient;
  final LocalCache _cache;

  static const _incidentTypesKey = 'incident_types';

  @override
  Future<List<IncidentType>> getIncidentTypes() async {
    //1.- Intentamos recuperar la lista desde la caché para soportar modo offline.
    final cached = await _cache.read(_incidentTypesKey);
    if (cached != null) {
      final items = List<Map<String, dynamic>>.from(cached['items'] as List<dynamic>);
      //2.- Transformamos el contenido cacheado en entidades de dominio.
      return items.map(IncidentTypeMapper.fromMap).toList();
    }
    //3.- Si no hay caché, consultamos al API y almacenamos la respuesta.
    final incidentTypes = await _apiClient.fetchIncidentTypes();
    await _cache.write(_incidentTypesKey, {
      'items': incidentTypes
          .map((type) => {
                'id': type.id,
                'name': type.name,
                'requiresEvidence': type.requiresEvidence,
              })
          .toList(),
    });
    return incidentTypes;
  }
}
