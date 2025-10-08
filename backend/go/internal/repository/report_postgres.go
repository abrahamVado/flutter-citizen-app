package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"citizenapp/backend/internal/service"
)

// 1.- PostgresReportRepository implementa service.ReportRepository con SQL estándar.
type PostgresReportRepository struct {
	db *sql.DB
}

// 2.- NewPostgresReportRepository inyecta la conexión *sql.DB ya configurada.
func NewPostgresReportRepository(db *sql.DB) *PostgresReportRepository {
	if db == nil {
		panic("postgres db is required")
	}
	return &PostgresReportRepository{db: db}
}

// 3.- Create inserta el reporte y devuelve el registro almacenado.
func (r *PostgresReportRepository) Create(ctx context.Context, report service.Report) (service.Report, error) {
	const query = `
                INSERT INTO reports (
                        id,
                        incident_type_id,
                        incident_type_name,
                        incident_type_requires_evidence,
                        description,
                        latitude,
                        longitude,
                        status,
                        created_at
                ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
                RETURNING incident_type_name, incident_type_requires_evidence
        `
	var name string
	var requires bool
	err := r.db.QueryRowContext(
		ctx,
		query,
		report.ID,
		report.IncidentType.ID,
		report.IncidentType.Name,
		report.IncidentType.RequiresEvidence,
		report.Description,
		report.Latitude,
		report.Longitude,
		report.Status,
		report.CreatedAt,
	).Scan(&name, &requires)
	if err != nil {
		return service.Report{}, err
	}
	report.IncidentType.Name = name
	report.IncidentType.RequiresEvidence = requires
	return report, nil
}

// 4.- FindByID obtiene el reporte persistido o ErrReportNotFound.
func (r *PostgresReportRepository) FindByID(ctx context.Context, id string) (service.Report, error) {
	const query = `
                SELECT
                        id,
                        incident_type_id,
                        incident_type_name,
                        incident_type_requires_evidence,
                        description,
                        latitude,
                        longitude,
                        status,
                        created_at
                FROM reports
                WHERE id = $1
        `
	var report service.Report
	var created time.Time
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&report.ID,
		&report.IncidentType.ID,
		&report.IncidentType.Name,
		&report.IncidentType.RequiresEvidence,
		&report.Description,
		&report.Latitude,
		&report.Longitude,
		&report.Status,
		&created,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return service.Report{}, service.ErrReportNotFound
		}
		return service.Report{}, err
	}
	report.CreatedAt = created
	return report, nil
}

// 5.- List devuelve los reportes paginados junto con el conteo total.
func (r *PostgresReportRepository) List(ctx context.Context, page, pageSize int, status string) ([]service.Report, int, error) {
	baseArgs := []any{}
	whereClause := ""
	if status != "" {
		whereClause = " WHERE status = $1"
		baseArgs = append(baseArgs, status)
	}
	countQuery := "SELECT COUNT(*) FROM reports" + whereClause
	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, baseArgs...).Scan(&total); err != nil {
		return nil, 0, err
	}
	if total == 0 {
		return []service.Report{}, 0, nil
	}
	offset := page * pageSize
	limitIndex := len(baseArgs) + 1
	offsetIndex := len(baseArgs) + 2
	listQuery := fmt.Sprintf(`
                SELECT
                        id,
                        incident_type_id,
                        incident_type_name,
                        incident_type_requires_evidence,
                        description,
                        latitude,
                        longitude,
                        status,
                        created_at
                FROM reports%s
                ORDER BY created_at DESC
                LIMIT $%d OFFSET $%d
        `, whereClause, limitIndex, offsetIndex)
	args := append([]any{}, baseArgs...)
	args = append(args, pageSize, offset)
	rows, err := r.db.QueryContext(ctx, listQuery, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	reports := make([]service.Report, 0)
	for rows.Next() {
		var report service.Report
		var created time.Time
		if err := rows.Scan(
			&report.ID,
			&report.IncidentType.ID,
			&report.IncidentType.Name,
			&report.IncidentType.RequiresEvidence,
			&report.Description,
			&report.Latitude,
			&report.Longitude,
			&report.Status,
			&created,
		); err != nil {
			return nil, 0, err
		}
		report.CreatedAt = created
		reports = append(reports, report)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}
	return reports, total, nil
}

// 6.- Delete remueve el reporte devolviendo ErrReportNotFound si no existe.
func (r *PostgresReportRepository) Delete(ctx context.Context, id string) error {
	result, err := r.db.ExecContext(ctx, "DELETE FROM reports WHERE id = $1", id)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return service.ErrReportNotFound
	}
	return nil
}

// 7.- Lookup construye el seguimiento del folio reutilizando FindByID.
func (r *PostgresReportRepository) Lookup(ctx context.Context, id string) (service.FolioStatus, error) {
	report, err := r.FindByID(ctx, id)
	if err != nil {
		return service.FolioStatus{}, err
	}
	status := service.FolioStatus{
		Folio:      report.ID,
		Status:     report.Status,
		LastUpdate: time.Now(),
		History: []string{
			"Reporte recibido",
			"Asignado a cuadrilla",
		},
	}
	return status, nil
}

// 8.- UpdateStatusWithMetrics utiliza una transacción para mantener consistencia.
func (r *PostgresReportRepository) UpdateStatusWithMetrics(ctx context.Context, id, status string) (service.Report, service.AdminDashboardMetrics, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return service.Report{}, service.AdminDashboardMetrics{}, err
	}
	const updateQuery = `
                UPDATE reports
                SET status = $1
                WHERE id = $2
                RETURNING
                        id,
                        incident_type_id,
                        incident_type_name,
                        incident_type_requires_evidence,
                        description,
                        latitude,
                        longitude,
                        status,
                        created_at
        `
	var report service.Report
	var created time.Time
	err = tx.QueryRowContext(ctx, updateQuery, status, id).Scan(
		&report.ID,
		&report.IncidentType.ID,
		&report.IncidentType.Name,
		&report.IncidentType.RequiresEvidence,
		&report.Description,
		&report.Latitude,
		&report.Longitude,
		&report.Status,
		&created,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			tx.Rollback()
			return service.Report{}, service.AdminDashboardMetrics{}, service.ErrReportNotFound
		}
		tx.Rollback()
		return service.Report{}, service.AdminDashboardMetrics{}, err
	}
	report.CreatedAt = created
	metrics, err := r.metricsFromTx(ctx, tx)
	if err != nil {
		tx.Rollback()
		return service.Report{}, service.AdminDashboardMetrics{}, err
	}
	if err := tx.Commit(); err != nil {
		return service.Report{}, service.AdminDashboardMetrics{}, err
	}
	return report, metrics, nil
}

// 9.- Metrics recupera los totales agregados del almacenamiento.
func (r *PostgresReportRepository) Metrics(ctx context.Context) (service.AdminDashboardMetrics, error) {
	return r.metricsFromTx(ctx, r.db)
}

// 10.- metricsFromTx centraliza el cálculo de conteos según el contexto SQL.
func (r *PostgresReportRepository) metricsFromTx(ctx context.Context, runner interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}) (service.AdminDashboardMetrics, error) {
	const query = `
                SELECT
                        COALESCE(SUM(CASE WHEN status = 'en_revision' THEN 1 ELSE 0 END), 0) AS pending,
                        COALESCE(SUM(CASE WHEN status = 'resuelto' THEN 1 ELSE 0 END), 0) AS resolved,
                        COALESCE(SUM(CASE WHEN status = 'critico' THEN 1 ELSE 0 END), 0) AS critical
                FROM reports
        `
	var metrics service.AdminDashboardMetrics
	row := runner.QueryRowContext(ctx, query)
	if err := row.Scan(&metrics.PendingReports, &metrics.ResolvedReports, &metrics.CriticalIncidents); err != nil {
		if err == sql.ErrNoRows {
			return service.AdminDashboardMetrics{}, nil
		}
		return service.AdminDashboardMetrics{}, err
	}
	return metrics, nil
}
