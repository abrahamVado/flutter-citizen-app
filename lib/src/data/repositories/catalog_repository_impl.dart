import '../../domain/entities/incident_type.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../cache/local_cache.dart';
import '../datasources/api_client.dart';
import '../models/mappers.dart';
import '../../utils/cache/cache_box.dart';
import '../../utils/cache/concurrency_safe_cache.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required ApiClient apiClient,
    required LocalCache cache,
  }) : _apiClient = apiClient,
       _incidentTypesBox = CacheBox<List<IncidentType>>(
         cache: ConcurrencySafeCache(cache),
         key: _incidentTypesKey,
         encode: _encodeIncidentTypes,
         decode: _decodeIncidentTypes,
       );

  final ApiClient _apiClient;
  final CacheBox<List<IncidentType>> _incidentTypesBox;

  static const _incidentTypesKey = 'incident_types';

  static Map<String, dynamic> _encodeIncidentTypes(List<IncidentType> items) {
    //1.- Serializamos cada elemento a un mapa simple para almacenarlo en caché.
    return {
      'items': items
          .map(
            (type) => {
              'id': type.id,
              'name': type.name,
              'requiresEvidence': type.requiresEvidence,
            },
          )
          .toList(),
    };
  }

  static List<IncidentType> _decodeIncidentTypes(Map<String, dynamic> map) {
    //1.- Reconstruimos la lista tipada utilizando el mapper existente.
    final rawItems = List<Map<String, dynamic>>.from(
      map['items'] as List<dynamic>,
    );
    return rawItems.map(IncidentTypeMapper.fromMap).toList();
  }

  @override
  Future<List<IncidentType>> getIncidentTypes() async {
    //1.- Intentamos recuperar la lista desde la caché tipada para soportar modo offline.
    final cached = await _incidentTypesBox.read();
    if (cached != null) {
      return cached;
    }
    //2.- Si no hay caché consultamos al API y persistimos la respuesta.
    final incidentTypes = await _apiClient.fetchIncidentTypes();
    await _incidentTypesBox.write(incidentTypes);
    //3.- Entregamos la lista descargada a la capa de dominio.
    return incidentTypes;
  }
}
