import '../entities/folio_status.dart';
import '../entities/report.dart';

abstract class ReportsRepository {
  Future<Report> submitReport(ReportRequest request);
  Future<FolioStatus> lookupFolio(String folio);
}
