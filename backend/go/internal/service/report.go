package service

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
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
	resultCh chan<- Report
}

type lookupJob struct {
	ctx      context.Context
	folio    string
	resultCh chan<- FolioStatus
}

// 3.- ReportService orquesta los pools de envío y consulta.
type ReportService struct {
	submitJobs chan submitJob
	lookupJobs chan lookupJob
	mutex      sync.RWMutex
	records    map[string]Report
	rand       *rand.Rand
	randMutex  sync.Mutex
}

// 4.- NewReportService inicializa los trabajadores concurrentes.
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

// 5.- Submit genera un folio y almacena el reporte en memoria.
func (s *ReportService) Submit(ctx context.Context, payload map[string]any) (Report, error) {
	resultCh := make(chan Report, 1)
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
		return res, nil
	}
}

// 6.- Lookup consulta el almacenamiento concurrente y devuelve el historial.
func (s *ReportService) Lookup(ctx context.Context, folio string) (FolioStatus, error) {
	resultCh := make(chan FolioStatus, 1)
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
		return res, nil
	}
}

func (s *ReportService) submitWorker() {
	for job := range s.submitJobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		// 7.- Asignamos folios pseudoaleatorios y persistimos el reporte.
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
		job.resultCh <- report
	}
}

func (s *ReportService) lookupWorker() {
	for job := range s.lookupJobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		// 8.- Leemos el reporte y construimos un historial simulado.
		s.mutex.RLock()
		report, ok := s.records[job.folio]
		s.mutex.RUnlock()
		if !ok {
			job.resultCh <- FolioStatus{
				Folio:      job.folio,
				Status:     "no_encontrado",
				LastUpdate: time.Now(),
				History:    []string{"Folio inexistente"},
			}
			continue
		}
		status := FolioStatus{
			Folio:      report.ID,
			Status:     "en_proceso",
			LastUpdate: time.Now(),
			History: []string{
				"Reporte recibido",
				"Asignado a cuadrilla",
			},
		}
		job.resultCh <- status
	}
}

// 9.- toFloat homogeniza los datos numéricos recibidos.
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
