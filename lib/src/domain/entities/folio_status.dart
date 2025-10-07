import 'package:equatable/equatable.dart';

class FolioStatus extends Equatable {
  const FolioStatus({
    required this.folio,
    required this.status,
    required this.lastUpdate,
    required this.history,
  });

  final String folio;
  final String status;
  final DateTime lastUpdate;
  final List<String> history;

  @override
  List<Object?> get props => [folio, status, lastUpdate, history];
}
