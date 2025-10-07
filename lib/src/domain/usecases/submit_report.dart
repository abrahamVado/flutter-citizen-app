import '../entities/report.dart';
import '../exceptions/validation_exception.dart';
import '../repositories/reports_repository.dart';

class SubmitReport {
  SubmitReport({required ReportsRepository reportsRepository})
      : _reportsRepository = reportsRepository;

  final ReportsRepository _reportsRepository;

  Future<Report> call(ReportRequest request) {
    //1.- Validamos que el correo y el teléfono estén presentes replicando las reglas web.
    if (request.contactEmail.trim().isEmpty) {
      throw const ValidationException('El correo de contacto es obligatorio.');
    }
    //2.- Revisamos que el teléfono tenga al menos 10 dígitos para facilitar contacto.
    if (request.contactPhone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      throw const ValidationException('El teléfono debe tener al menos 10 dígitos.');
    }
    //3.- Validamos que la descripción esté presente para contextualizar el incidente.
    if (request.description.trim().length < 10) {
      throw const ValidationException('Describe el incidente con al menos 10 caracteres.');
    }
    //4.- Delegamos la creación del reporte al repositorio de datos.
    return _reportsRepository.submitReport(request);
  }
}
