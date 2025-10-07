import 'package:equatable/equatable.dart';

import '../../../domain/entities/incident_type.dart';
import '../../../domain/entities/report.dart';

enum ReportFormStatus { idle, loading, success, error }

class ReportFormState extends Equatable {
  const ReportFormState({
    required this.description,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.selectedTypeId,
    required this.types,
    required this.status,
    this.submittedReport,
    this.errorMessage,
  });

  const ReportFormState.initial()
      : this(
          description: '',
          contactEmail: '',
          contactPhone: '',
          address: '',
          latitude: 19.4326,
          longitude: -99.1332,
          selectedTypeId: null,
          types: const [],
          status: ReportFormStatus.idle,
        );

  final String description;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final double latitude;
  final double longitude;
  final String? selectedTypeId;
  final List<IncidentType> types;
  final ReportFormStatus status;
  final Report? submittedReport;
  final String? errorMessage;

  ReportFormState copyWith({
    String? description,
    String? contactEmail,
    String? contactPhone,
    String? address,
    double? latitude,
    double? longitude,
    String? selectedTypeId,
    List<IncidentType>? types,
    ReportFormStatus? status,
    Report? submittedReport,
    String? errorMessage,
  }) {
    //1.- Retornamos un nuevo estado manteniendo el resto de propiedades intactas.
    return ReportFormState(
      description: description ?? this.description,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      selectedTypeId: selectedTypeId ?? this.selectedTypeId,
      types: types ?? this.types,
      status: status ?? this.status,
      submittedReport: submittedReport,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        description,
        contactEmail,
        contactPhone,
        address,
        latitude,
        longitude,
        selectedTypeId,
        types,
        status,
        submittedReport,
        errorMessage,
      ];
}
