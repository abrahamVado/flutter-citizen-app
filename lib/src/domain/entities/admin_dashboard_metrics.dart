import 'package:equatable/equatable.dart';

class AdminDashboardMetrics extends Equatable {
  const AdminDashboardMetrics({
    required this.pendingReports,
    required this.resolvedReports,
    required this.criticalIncidents,
  });

  //1.- Almacenamos el total de reportes en espera de atención.
  final int pendingReports;
  //2.- Almacenamos el total de reportes resueltos por las cuadrillas.
  final int resolvedReports;
  //3.- Almacenamos el total de incidentes que requieren prioridad crítica.
  final int criticalIncidents;

  @override
  List<Object?> get props => [
    pendingReports,
    resolvedReports,
    criticalIncidents,
  ];
}
