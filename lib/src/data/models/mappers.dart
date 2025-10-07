import '../../domain/entities/folio_status.dart';
import '../../domain/entities/incident_type.dart';
import '../../domain/entities/report.dart';

class IncidentTypeMapper {
  static IncidentType fromMap(Map<String, dynamic> map) {
    //1.- Convertimos el mapa bruto en la entidad de dominio equivalente.
    return IncidentType(
      id: map['id'] as String,
      name: map['name'] as String,
      requiresEvidence: map['requiresEvidence'] as bool,
    );
  }
}

class ReportMapper {
  static Report fromMap(Map<String, dynamic> map) {
    //1.- Reconstruimos el tipo de incidente utilizando el mapper especializado.
    final incidentType = IncidentTypeMapper.fromMap(map['incidentType'] as Map<String, dynamic>);
    //2.- Devolvemos el Report con los campos fuertemente tipados.
    return Report(
      id: map['id'] as String,
      incidentType: incidentType,
      description: map['description'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class ReportRequestMapper {
  static Map<String, dynamic> toMap(ReportRequest request) {
    //1.- Serializamos la petición asegurando el contrato esperado por el backend.
    return {
      'incidentTypeId': request.incidentTypeId,
      'description': request.description,
      'contactEmail': request.contactEmail,
      'contactPhone': request.contactPhone,
      'latitude': request.latitude,
      'longitude': request.longitude,
      'address': request.address,
    };
  }
}

class FolioStatusMapper {
  static FolioStatus fromMap(Map<String, dynamic> map) {
    //1.- Creamos el historial asegurando tipos correctos en la lista.
    final history = List<String>.from(map['history'] as List<dynamic>);
    //2.- Devolvemos el objeto de dominio utilizado por la UI.
    return FolioStatus(
      folio: map['folio'] as String,
      status: map['status'] as String,
      lastUpdate: DateTime.parse(map['lastUpdate'] as String),
      history: history,
    );
  }
}
