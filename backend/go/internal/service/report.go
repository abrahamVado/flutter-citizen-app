package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"sort"
	"strings"
	"sync"
	"time"
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

// 5.- ReportService orquesta los pools de envío y consulta.
type ReportService struct {
	submitJobs chan submitJob
	lookupJobs chan lookupJob
	mutex      sync.RWMutex
	records    map[string]Report
	rand       *rand.Rand
	randMutex  sync.Mutex
}

// 6.- Errores compartidos para mapear estados HTTP coherentes.
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

// 7.- NewReportService inicializa los trabajadores concurrentes.
func NewReportService(submitWorkers, lookupWorkers int) *ReportService {
	s := &ReportService{
		submitJobs: make(chan submitJob),
		lookupJobs: make(chan lookupJob),
		records:    make(map[string]Report),
		rand:       rand.New(rand.NewSource(time.Now().UnixNano())),
	}
	for i := 0; i < submitWorkers; i++ {
		go s.submitWorker()
	}
	for i := 0; i < lookupWorkers; i++ {
		go s.lookupWorker()
	}
	return s
}

// 8.- Submit genera un folio y almacena el reporte en memoria.
func (s *ReportService) Submit(ctx context.Context, payload map[string]any) (Report, error) {
	resultCh := make(chan submitResult, 1)
	job := submitJob{ctx: ctx, payload: payload, resultCh: resultCh}
	select {
	case <-ctx.Done():
		return Report{}, ctx.Err()
	case s.submitJobs <- job:
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

// 9.- Lookup consulta el almacenamiento concurrente y devuelve el historial.
func (s *ReportService) Lookup(ctx context.Context, folio string) (FolioStatus, error) {
	resultCh := make(chan lookupResult, 1)
	job := lookupJob{ctx: ctx, folio: folio, resultCh: resultCh}
	select {
	case <-ctx.Done():
		return FolioStatus{}, ctx.Err()
	case s.lookupJobs <- job:
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

// 10.- List aplica paginación en memoria con filtros opcionales.
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
	s.mutex.RLock()
	items := make([]Report, 0, len(s.records))
	for _, report := range s.records {
		if trimmed != "" && report.Status != trimmed {
			continue
		}
		items = append(items, report)
	}
	s.mutex.RUnlock()
	sort.Slice(items, func(i, j int) bool {
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})
	total := len(items)
	start := page * pageSize
	if start > total {
		start = total
	}
	end := start + pageSize
	if end > total {
		end = total
	}
	paginated := items[start:end]
	hasMore := end < total
	return PaginatedReports{Items: paginated, HasMore: hasMore, Page: page, TotalCount: total}, nil
}

// 11.- Get obtiene un reporte puntual por identificador.
func (s *ReportService) Get(ctx context.Context, id string) (Report, error) {
	select {
	case <-ctx.Done():
		return Report{}, ctx.Err()
	default:
	}
	s.mutex.RLock()
	report, exists := s.records[id]
	s.mutex.RUnlock()
	if !exists {
		return Report{}, ErrReportNotFound
	}
	return report, nil
}

// 12.- UpdateStatus valida y actualiza el estatus de un reporte.
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
	s.mutex.Lock()
	defer s.mutex.Unlock()
	report, exists := s.records[id]
	if !exists {
		return Report{}, ErrReportNotFound
	}
	report.Status = trimmed
	s.records[id] = report
	return report, nil
}

// 13.- Delete elimina un reporte del almacenamiento en memoria.
func (s *ReportService) Delete(ctx context.Context, id string) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}
	s.mutex.Lock()
	defer s.mutex.Unlock()
	if _, exists := s.records[id]; !exists {
		return ErrReportNotFound
	}
	delete(s.records, id)
	return nil
}

// 14.- DashboardMetrics consolida los totales para el panel de control.
func (s *ReportService) DashboardMetrics(ctx context.Context) (AdminDashboardMetrics, error) {
	select {
	case <-ctx.Done():
		return AdminDashboardMetrics{}, ctx.Err()
	default:
	}
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	metrics := AdminDashboardMetrics{}
	for _, report := range s.records {
		switch report.Status {
		case "en_revision":
			metrics.PendingReports++
		case "resuelto":
			metrics.ResolvedReports++
		case "critico":
			metrics.CriticalIncidents++
		}
	}
	return metrics, nil
}

func (s *ReportService) submitWorker() {
	for job := range s.submitJobs {
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
		s.mutex.Lock()
		s.records[id] = report
		s.mutex.Unlock()
		job.resultCh <- submitResult{report: report}
	}
}

func (s *ReportService) lookupWorker() {
	for job := range s.lookupJobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		s.mutex.RLock()
		report, ok := s.records[job.folio]
		s.mutex.RUnlock()
		if !ok {
			job.resultCh <- lookupResult{err: ErrReportNotFound}
			continue
		}
		status := FolioStatus{
			Folio:      report.ID,
			Status:     report.Status,
			LastUpdate: time.Now(),
			History: []string{
				"Reporte recibido",
				"Asignado a cuadrilla",
			},
		}
		job.resultCh <- lookupResult{status: status}
	}
}

// 15.- toFloat homogeniza los datos numéricos recibidos.
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
