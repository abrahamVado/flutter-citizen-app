import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/report.dart';
import '../../../domain/exceptions/validation_exception.dart';
import '../../../domain/usecases/get_incident_types.dart';
import '../../../domain/usecases/submit_report.dart';
import 'report_form_state.dart';

final reportFormControllerProvider =
    StateNotifierProvider.autoDispose<ReportFormController, ReportFormState>((ref) {
  //1.- Creamos el controlador inyectando los casos de uso y cargando catálogos al iniciar.
  final controller = ReportFormController(
    submitReport: ref.watch(submitReportProvider),
    getIncidentTypes: ref.watch(getIncidentTypesProvider),
  );
  controller.loadIncidentTypes();
  return controller;
});

class ReportFormController extends StateNotifier<ReportFormState> {
  ReportFormController({required SubmitReport submitReport, required GetIncidentTypes getIncidentTypes})
      : _submitReport = submitReport,
        _getIncidentTypes = getIncidentTypes,
        super(const ReportFormState.initial());

  final SubmitReport _submitReport;
  final GetIncidentTypes _getIncidentTypes;

  void updateDescription(String value) {
    //1.- Actualizamos la descripción para que la UI mantenga el formulario sincronizado.
    state = state.copyWith(description: value);
  }

  void updateContactEmail(String value) {
    //1.- Guardamos el correo en el estado para validarlo durante el envío.
    state = state.copyWith(contactEmail: value);
  }

  void updateContactPhone(String value) {
    //1.- Guardamos el teléfono manteniendo el seguimiento de cambios.
    state = state.copyWith(contactPhone: value);
  }

  void updateAddress(String value) {
    //1.- Permitimos modificar la dirección textual obtenida desde geocodificación.
    state = state.copyWith(address: value);
  }

  void selectIncidentType(String? id) {
    //1.- Actualizamos el identificador seleccionado para enviar el reporte al backend.
    state = state.copyWith(selectedTypeId: id);
  }

  Future<void> loadIncidentTypes() async {
    //1.- Cambiamos a estado de carga para indicar progreso al usuario.
    state = state.copyWith(status: ReportFormStatus.loading);
    try {
      //2.- Consultamos los tipos y los guardamos para poblar el dropdown.
      final types = await _getIncidentTypes();
      state = state.copyWith(types: types, status: ReportFormStatus.idle);
    } catch (error) {
      //3.- Ante un fallo mostramos un error amigable.
      state = state.copyWith(status: ReportFormStatus.error, errorMessage: error.toString());
    }
  }

  Future<void> submit() async {
    //1.- Evitamos envíos múltiples si ya estamos procesando otro reporte.
    if (state.status == ReportFormStatus.loading) {
      return;
    }
    state = state.copyWith(status: ReportFormStatus.loading, errorMessage: null);
    try {
      //2.- Validamos la selección de tipo antes de construir la petición.
      final typeId = state.selectedTypeId;
      if (typeId == null) {
        throw const ValidationException('Selecciona un tipo de incidente.');
      }
      //3.- Ejecutamos el caso de uso con la información capturada.
      final report = await _submitReport(
        ReportRequest(
          incidentTypeId: typeId,
          description: state.description,
          contactEmail: state.contactEmail,
          contactPhone: state.contactPhone,
          latitude: state.latitude,
          longitude: state.longitude,
          address: state.address,
        ),
      );
      //4.- Actualizamos el estado marcando éxito y guardando el reporte resultante.
      state = state.copyWith(status: ReportFormStatus.success, submittedReport: report);
    } on ValidationException catch (error) {
      //5.- Traducimos los errores de validación para mostrarlos en la UI.
      state = state.copyWith(status: ReportFormStatus.error, errorMessage: error.message);
    } catch (error) {
      //6.- Capturamos cualquier otro error inesperado y lo exponemos al usuario.
      state = state.copyWith(status: ReportFormStatus.error, errorMessage: error.toString());
    }
  }
}
