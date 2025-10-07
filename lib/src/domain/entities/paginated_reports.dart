import 'package:equatable/equatable.dart';

import 'report.dart';

class PaginatedReports extends Equatable {
  const PaginatedReports({
    required this.items,
    required this.hasMore,
    required this.page,
  });

  //1.- Contiene los reportes incluidos en la página solicitada.
  final List<Report> items;
  //2.- Indica si el backend tiene más información disponible para paginar.
  final bool hasMore;
  //3.- Conservamos el número de página actual para cálculos subsecuentes.
  final int page;

  PaginatedReports copyWith({List<Report>? items, bool? hasMore, int? page}) {
    //1.- Creamos una copia para mantener inmutabilidad en la capa de presentación.
    return PaginatedReports(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }

  @override
  List<Object?> get props => [items, hasMore, page];
}
