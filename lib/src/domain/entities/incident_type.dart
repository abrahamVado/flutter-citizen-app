import 'package:equatable/equatable.dart';

class IncidentType extends Equatable {
  const IncidentType({required this.id, required this.name, required this.requiresEvidence});

  final String id;
  final String name;
  final bool requiresEvidence;

  @override
  List<Object?> get props => [id, name, requiresEvidence];
}
