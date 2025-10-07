import 'package:equatable/equatable.dart';

import 'incident_type.dart';

class Report extends Equatable {
  const Report({
    required this.id,
    required this.incidentType,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final IncidentType incidentType;
  final String description;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        incidentType,
        description,
        latitude,
        longitude,
        status,
        createdAt,
      ];
}

class ReportRequest {
  const ReportRequest({
    required this.incidentTypeId,
    required this.description,
    required this.contactEmail,
    required this.contactPhone,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final String incidentTypeId;
  final String description;
  final String contactEmail;
  final String contactPhone;
  final double latitude;
  final double longitude;
  final String address;
}
