import '../entities/folio_status.dart';
import '../repositories/reports_repository.dart';

class LookupFolio {
  const LookupFolio({required ReportsRepository reportsRepository})
      : _reportsRepository = reportsRepository;

  final ReportsRepository _reportsRepository;

  Future<FolioStatus> call(String folio) {
    //1.- Normalizamos el folio antes de delegar la consulta al repositorio.
    final sanitizedFolio = folio.trim().toUpperCase();
    //2.- Ejecutamos la consulta asegurando que la UI reciba un objeto de dominio.
    return _reportsRepository.lookupFolio(sanitizedFolio);
  }
}
