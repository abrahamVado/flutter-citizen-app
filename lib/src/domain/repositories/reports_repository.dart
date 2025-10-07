import '../entities/admin_dashboard_metrics.dart';
import '../entities/folio_status.dart';
import '../entities/paginated_reports.dart';
import '../entities/report.dart';

abstract class ReportsRepository {
  Future<AdminDashboardMetrics> fetchDashboardMetrics();
  Future<PaginatedReports> fetchReports({
    required int page,
    required int pageSize,
  });
  Future<Report> fetchReportById(String id);
  Future<Report> updateReportStatus({
    required String id,
    required String status,
  });
  Future<void> deleteReport(String id);
  Future<Report> submitReport(ReportRequest request);
  Future<FolioStatus> lookupFolio(String folio);
}
