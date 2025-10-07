import '../entities/incident_type.dart';
import '../repositories/catalog_repository.dart';

class GetIncidentTypes {
  const GetIncidentTypes({required CatalogRepository catalogRepository})
      : _catalogRepository = catalogRepository;

  final CatalogRepository _catalogRepository;

  Future<List<IncidentType>> call() {
    //1.- Delegamos al repositorio la obtención de tipos, manteniendo la UI desacoplada.
    return _catalogRepository.getIncidentTypes();
  }
}
