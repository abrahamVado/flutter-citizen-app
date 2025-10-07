import '../entities/incident_type.dart';

abstract class CatalogRepository {
  Future<List<IncidentType>> getIncidentTypes();
}
