import 'package:flutter_test/flutter_test.dart';

import 'package:citizen_reports_flutter/src/domain/entities/folio_status.dart';
import 'package:citizen_reports_flutter/src/domain/entities/incident_type.dart';
import 'package:citizen_reports_flutter/src/domain/entities/report.dart';
import 'package:citizen_reports_flutter/src/domain/exceptions/validation_exception.dart';
import 'package:citizen_reports_flutter/src/domain/repositories/reports_repository.dart';
import 'package:citizen_reports_flutter/src/domain/usecases/submit_report.dart';

class _RecordingReportsRepository implements ReportsRepository {
  _RecordingReportsRepository();

  int submitCallCount = 0;
  ReportRequest? lastRequest;

  @override
  Future<Report> submitReport(ReportRequest request) async {
    //1.- Registramos la cantidad de envíos para confirmar que solo se llama en el flujo feliz.
    submitCallCount++;
    //2.- Guardamos la solicitud para comprobar que llega intacta al repositorio.
    lastRequest = request;
    //3.- Respondemos con un reporte simulado para cerrar el recorrido exitoso.
    return Report(
      id: 'F-99999',
      incidentType: IncidentType(
        id: request.incidentTypeId,
        name: 'Incidente',
        requiresEvidence: false,
      ),
      description: request.description,
      latitude: request.latitude,
      longitude: request.longitude,
      status: 'en_revision',
      createdAt: DateTime(2024, 1, 1),
    );
  }

  @override
  Future<FolioStatus> lookupFolio(String folio) {
    //1.- Este caso de uso no consulta folios, por lo que mantenemos la implementación vacía.
    throw UnimplementedError();
  }
}

void main() {
  group('SubmitReport validations', () {
    late _RecordingReportsRepository repository;
    late SubmitReport submitReport;

    setUp(() {
      //1.- Instanciamos el repositorio falso que registrará las invocaciones.
      repository = _RecordingReportsRepository();
      //2.- Construimos el caso de uso con el repositorio preparado para la prueba.
      submitReport = SubmitReport(reportsRepository: repository);
    });

    test('delegates to repository when input is valid', () async {
      //1.- Preparamos una solicitud completa con datos representativos de la aplicación.
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Lámpara apagada desde hace tres noches en la esquina.',
        contactEmail: 'vecino@example.com',
        contactPhone: '5512345678',
        latitude: 19.4326,
        longitude: -99.1332,
        address: 'Av. Principal 100',
      );
      //2.- Ejecutamos el caso de uso para recorrer el flujo feliz.
      final report = await submitReport(request);
      //3.- Verificamos que el repositorio recibió exactamente una llamada con la solicitud original.
      expect(repository.submitCallCount, equals(1));
      expect(repository.lastRequest, same(request));
      //4.- Confirmamos que el reporte retornado es el simulado por el repositorio.
      expect(report.id, equals('F-99999'));
    });

    test('throws ValidationException when email is empty', () {
      //1.- Construimos una solicitud con correo en blanco para disparar la validación.
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Lámpara apagada desde hace tres noches en la esquina.',
        contactEmail: '   ',
        contactPhone: '5512345678',
        latitude: 19.4326,
        longitude: -99.1332,
        address: 'Av. Principal 100',
      );
      //2.- Comprobamos que el caso de uso lanza la excepción de validación esperada.
      expect(() => submitReport(request), throwsA(isA<ValidationException>()));
      //3.- Aseguramos que el repositorio no fue invocado debido a la falla de validación.
      expect(repository.submitCallCount, equals(0));
    });

    test('throws ValidationException when phone is too short', () {
      //1.- Creamos una solicitud con teléfono de menos de diez dígitos.
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Lámpara apagada desde hace tres noches en la esquina.',
        contactEmail: 'vecino@example.com',
        contactPhone: '12345',
        latitude: 19.4326,
        longitude: -99.1332,
        address: 'Av. Principal 100',
      );
      //2.- Validamos que se arroje la excepción correspondiente al teléfono inválido.
      expect(() => submitReport(request), throwsA(isA<ValidationException>()));
      //3.- Confirmamos que el repositorio se mantiene sin llamadas.
      expect(repository.submitCallCount, equals(0));
    });

    test('throws ValidationException when description is too short', () {
      //1.- Generamos una solicitud cuya descripción no alcanza el mínimo permitido.
      final request = ReportRequest(
        incidentTypeId: 'lighting',
        description: 'Muy corto',
        contactEmail: 'vecino@example.com',
        contactPhone: '5512345678',
        latitude: 19.4326,
        longitude: -99.1332,
        address: 'Av. Principal 100',
      );
      //2.- Evaluamos que se produzca la excepción de validación correspondiente.
      expect(() => submitReport(request), throwsA(isA<ValidationException>()));
      //3.- Observamos que no se enviaron solicitudes al repositorio.
      expect(repository.submitCallCount, equals(0));
    });
  });
}
