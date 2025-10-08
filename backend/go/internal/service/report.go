package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"time"

	"citizenapp/backend/internal/observability"
	"github.com/rs/zerolog"
)

// 1.- Report representa la respuesta serializada para los reportes.
type Report struct {
	ID           string       `json:"id"`
	IncidentType IncidentType `json:"incidentType"`
	Description  string       `json:"description"`
	Latitude     float64      `json:"latitude"`
	Longitude    float64      `json:"longitude"`
	Status       string       `json:"status"`
	CreatedAt    time.Time    `json:"createdAt"`
}

// 2.- FolioStatus encapsula el seguimiento de cada folio solicitado.
type FolioStatus struct {
	Folio      string    `json:"folio"`
	Status     string    `json:"status"`
	LastUpdate time.Time `json:"lastUpdate"`
	History    []string  `json:"history"`
}

type submitJob struct {
	ctx      context.Context
	payload  map[string]any
	resultCh chan<- submitResult
}

type submitResult struct {
	report Report
	err    error
}

type lookupJob struct {
	ctx      context.Context
	folio    string
	resultCh chan<- lookupResult
}

type lookupResult struct {
	status FolioStatus
	err    error
}

// 3.- PaginatedReports modela la respuesta esperada por /reports GET.
type PaginatedReports struct {
	Items      []Report `json:"items"`
	HasMore    bool     `json:"hasMore"`
	Page       int      `json:"page"`
	TotalCount int      `json:"totalCount"`
}

// 4.- AdminDashboardMetrics resume los conteos para el panel administrativo.
type AdminDashboardMetrics struct {
	PendingReports    int `json:"pendingReports"`
	ResolvedReports   int `json:"resolvedReports"`
	CriticalIncidents int `json:"criticalIncidents"`
}

// 5.- ReportRepository define el contrato de persistencia para reportes.
type ReportRepository interface {
	Create(ctx context.Context, report Report) (Report, error)
	FindByID(ctx context.Context, id string) (Report, error)
	List(ctx context.Context, page, pageSize int, status string) ([]Report, int, error)
	Delete(ctx context.Context, id string) error
	Lookup(ctx context.Context, id string) (FolioStatus, error)
	UpdateStatusWithMetrics(ctx context.Context, id, status string) (Report, AdminDashboardMetrics, error)
	Metrics(ctx context.Context) (AdminDashboardMetrics, error)
}

// 6.- ReportService orquesta los pools de envío y consulta.
type ReportService struct {
	submitJobs chan submitJob
	lookupJobs chan lookupJob
	repo       ReportRepository
	rand       *rand.Rand
	randMutex  sync.Mutex
	// 6.1.- logger documenta los eventos para auditoría estructurada.
	logger zerolog.Logger
}

// 7.- Errores compartidos para mapear estados HTTP coherentes.
var (
	ErrReportNotFound = errors.New("report not found")
	ErrInvalidStatus  = errors.New("invalid status")
)

var allowedStatuses = map[string]struct{}{
	"en_revision": {},
	"en_proceso":  {},
	"resuelto":    {},
	"critico":     {},
}

// 8.- NewReportService inicializa los trabajadores concurrentes.
func NewReportService(repo ReportRepository, submitWorkers, lookupWorkers int) *ReportService {
	if repo == nil {
		panic("report repository is required")
	}
	observability.EnsureMetrics(nil)
	s := &ReportService{
		submitJobs: make(chan submitJob, max(32, submitWorkers*16)),
		lookupJobs: make(chan lookupJob, max(32, lookupWorkers*16)),
		repo:       repo,
		rand:       rand.New(rand.NewSource(time.Now().UnixNano())),
		logger:     observability.NamedLogger("report_service"),
	}
	observability.SetReportSubmitQueueDepth(len(s.submitJobs))
	observability.SetReportLookupQueueDepth(len(s.lookupJobs))
	for i := 0; i < submitWorkers; i++ {
		go s.submitWorker()
	}
	for i := 0; i < lookupWorkers; i++ {
		go s.lookupWorker()
	}
	return s
}

// 9.- Submit genera un folio y almacena el reporte en el repositorio.
func (s *ReportService) Submit(ctx context.Context, payload map[string]any) (Report, error) {
	resultCh := make(chan submitResult, 1)
	job := submitJob{ctx: ctx, payload: payload, resultCh: resultCh}
	select {
	case <-ctx.Done():
		return Report{}, ctx.Err()
	case s.submitJobs <- job:
		observability.SetReportSubmitQueueDepth(len(s.submitJobs))
	}
	select {
	case <-ctx.Done():
		return Report{}, ctx.Err()
	case res := <-resultCh:
		if res.err != nil {
			return Report{}, res.err
		}
		return res.report, nil
	}
}

// 10.- Lookup consulta el almacenamiento persistente y devuelve el historial.
func (s *ReportService) Lookup(ctx context.Context, folio string) (FolioStatus, error) {
	resultCh := make(chan lookupResult, 1)
	job := lookupJob{ctx: ctx, folio: folio, resultCh: resultCh}
	select {
	case <-ctx.Done():
		return FolioStatus{}, ctx.Err()
	case s.lookupJobs <- job:
		observability.SetReportLookupQueueDepth(len(s.lookupJobs))
	}
	select {
	case <-ctx.Done():
		return FolioStatus{}, ctx.Err()
	case res := <-resultCh:
		if res.err != nil {
			return FolioStatus{}, res.err
		}
		return res.status, nil
	}
}

// 11.- List delega la paginación al repositorio con filtros opcionales.
func (s *ReportService) List(ctx context.Context, page, pageSize int, status string) (PaginatedReports, error) {
	select {
	case <-ctx.Done():
		return PaginatedReports{}, ctx.Err()
	default:
	}
	trimmed := strings.TrimSpace(status)
	if trimmed != "" {
		if _, ok := allowedStatuses[trimmed]; !ok {
			return PaginatedReports{}, ErrInvalidStatus
		}
	}
	items, total, err := s.repo.List(ctx, page, pageSize, trimmed)
	if err != nil {
		return PaginatedReports{}, err
	}
	hasMore := (page+1)*pageSize < total
	return PaginatedReports{Items: items, HasMore: hasMore, Page: page, TotalCount: total}, nil
}

// 12.- Get obtiene un reporte puntual por identificador.
func (s *ReportService) Get(ctx context.Context, id string) (Report, error) {
	select {
	case <-ctx.Done():
		return Report{}, ctx.Err()
	default:
	}
	report, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return Report{}, err
	}
	return report, nil
}

// 13.- UpdateStatus valida y actualiza el estatus de un reporte.
func (s *ReportService) UpdateStatus(ctx context.Context, id, status string) (Report, error) {
	select {
	case <-ctx.Done():
		return Report{}, ctx.Err()
	default:
	}
	trimmed := strings.TrimSpace(status)
	if _, ok := allowedStatuses[trimmed]; !ok {
		return Report{}, ErrInvalidStatus
	}
	previous, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return Report{}, err
	}
	report, _, err := s.repo.UpdateStatusWithMetrics(ctx, id, trimmed)
	if err != nil {
		s.logger.Error().Err(err).Str("event", "report.status.update.failed").Str("report_id", id).Msg("unable to update report status")
		return Report{}, err
	}
	s.logger.Info().
		Str("event", "report.status.updated").
		Str("report_id", report.ID).
		Str("from_status", previous.Status).
		Str("to_status", report.Status).
		Msg("status transition recorded")
	return report, nil
}

// 14.- Delete elimina un reporte del almacenamiento persistente.
func (s *ReportService) Delete(ctx context.Context, id string) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}
	return s.repo.Delete(ctx, id)
}

// 15.- DashboardMetrics consolida los totales para el panel de control.
func (s *ReportService) DashboardMetrics(ctx context.Context) (AdminDashboardMetrics, error) {
	select {
	case <-ctx.Done():
		return AdminDashboardMetrics{}, ctx.Err()
	default:
	}
	return s.repo.Metrics(ctx)
}

func (s *ReportService) submitWorker() {
	for job := range s.submitJobs {
		observability.SetReportSubmitQueueDepth(len(s.submitJobs))
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		typeID, _ := job.payload["incidentTypeId"].(string)
		description, _ := job.payload["description"].(string)
		lat, _ := toFloat(job.payload["latitude"])
		lng, _ := toFloat(job.payload["longitude"])

		s.randMutex.Lock()
		folio := s.rand.Intn(90000) + 10000
		id := fmt.Sprintf("F-%05d", folio)
		s.randMutex.Unlock()

		report := Report{
			ID: id,
			IncidentType: IncidentType{
				ID:               typeID,
				Name:             "Incidente",
				RequiresEvidence: false,
			},
			Description: description,
			Latitude:    lat,
			Longitude:   lng,
			Status:      "en_revision",
			CreatedAt:   time.Now(),
		}
		stored, err := s.repo.Create(job.ctx, report)
		if err != nil {
			s.logger.Error().Err(err).Str("event", "report.submit.failed").Str("report_id", report.ID).Msg("unable to persist report")
			job.resultCh <- submitResult{err: err}
			continue
		}
		s.logger.Info().
			Str("event", "report.submit.completed").
			Str("report_id", stored.ID).
			Str("incident_type_id", stored.IncidentType.ID).
			Float64("latitude", stored.Latitude).
			Float64("longitude", stored.Longitude).
			Msg("report stored successfully")
		job.resultCh <- submitResult{report: stored}
	}
}

func (s *ReportService) lookupWorker() {
	for job := range s.lookupJobs {
		observability.SetReportLookupQueueDepth(len(s.lookupJobs))
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		status, err := s.repo.Lookup(job.ctx, job.folio)
		if err != nil {
			job.resultCh <- lookupResult{err: err}
			continue
		}
		job.resultCh <- lookupResult{status: status}
	}
}

// 16.- max retorna el valor más grande entre dos enteros.
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// 17.- toFloat homogeniza los datos numéricos recibidos.
func toFloat(value any) (float64, bool) {
	switch v := value.(type) {
	case float64:
		return v, true
	case float32:
		return float64(v), true
	case int:
		return float64(v), true
	case int64:
		return float64(v), true
	case json.Number:
		f, err := v.Float64()
		if err != nil {
			return 0, false
		}
		return f, true
	default:
		return 0, false
	}
}
