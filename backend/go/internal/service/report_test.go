package service

import (
	"context"
	"errors"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

// 1.- fakeReportRepository emula la persistencia para aislar las pruebas.
type fakeReportRepository struct {
	mu      sync.RWMutex
	records map[string]Report
}

func newFakeReportRepository() *fakeReportRepository {
	return &fakeReportRepository{records: make(map[string]Report)}
}

func (f *fakeReportRepository) Create(_ context.Context, report Report) (Report, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.records[report.ID] = report
	return report, nil
}

func (f *fakeReportRepository) FindByID(_ context.Context, id string) (Report, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	report, ok := f.records[id]
	if !ok {
		return Report{}, ErrReportNotFound
	}
	return report, nil
}

func (f *fakeReportRepository) List(_ context.Context, page, pageSize int, status string) ([]Report, int, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	items := make([]Report, 0, len(f.records))
	for _, report := range f.records {
		if status != "" && report.Status != status {
			continue
		}
		items = append(items, report)
	}
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
	return items[start:end], total, nil
}

func (f *fakeReportRepository) Delete(_ context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.records[id]; !ok {
		return ErrReportNotFound
	}
	delete(f.records, id)
	return nil
}

func (f *fakeReportRepository) Lookup(ctx context.Context, id string) (FolioStatus, error) {
	report, err := f.FindByID(ctx, id)
	if err != nil {
		return FolioStatus{}, err
	}
	return FolioStatus{
		Folio:      report.ID,
		Status:     report.Status,
		LastUpdate: time.Now(),
		History: []string{
			"Reporte recibido",
			"Asignado a cuadrilla",
		},
	}, nil
}

func (f *fakeReportRepository) UpdateStatusWithMetrics(ctx context.Context, id, status string) (Report, AdminDashboardMetrics, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	report, ok := f.records[id]
	if !ok {
		return Report{}, AdminDashboardMetrics{}, ErrReportNotFound
	}
	report.Status = status
	f.records[id] = report
	metrics := f.metricsLocked()
	return report, metrics, nil
}

func (f *fakeReportRepository) Metrics(_ context.Context) (AdminDashboardMetrics, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	return f.metricsLocked(), nil
}

func (f *fakeReportRepository) metricsLocked() AdminDashboardMetrics {
	metrics := AdminDashboardMetrics{}
	for _, report := range f.records {
		switch report.Status {
		case "en_revision":
			metrics.PendingReports++
		case "resuelto":
			metrics.ResolvedReports++
		case "critico":
			metrics.CriticalIncidents++
		}
	}
	return metrics
}

func TestReportSubmitAndLookupLifecycle(t *testing.T) {
	// 2.- Configuramos el servicio de reportes con pools dedicados.
	repo := newFakeReportRepository()
	svc := NewReportService(repo, 2, 2)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// 3.- Enviamos un reporte mínimo y validamos la respuesta generada.
	payload := map[string]any{
		"incidentTypeId": "pothole",
		"description":    "Bache profundo",
		"latitude":       19.43,
		"longitude":      -99.13,
	}
	report, err := svc.Submit(ctx, payload)
	if err != nil {
		t.Fatalf("Submit returned error: %v", err)
	}
	if !strings.HasPrefix(report.ID, "F-") {
		t.Fatalf("unexpected folio format: %s", report.ID)
	}
	if report.Status != "en_revision" {
		t.Fatalf("unexpected status: %s", report.Status)
	}

	// 4.- Consultamos el mismo folio y verificamos el historial simulado.
	status, err := svc.Lookup(ctx, report.ID)
	if err != nil {
		t.Fatalf("Lookup returned error: %v", err)
	}
	if status.Folio != report.ID {
		t.Fatalf("status mismatch: %s vs %s", status.Folio, report.ID)
	}
	if len(status.History) < 2 {
		t.Fatalf("expected history entries, got %d", len(status.History))
	}
}

func TestLookupReturnsNotFoundForUnknownFolio(t *testing.T) {
	// 1.- Iniciamos el servicio para consultar un folio inexistente.
	repo := newFakeReportRepository()
	svc := NewReportService(repo, 1, 1)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	// 2.- Ejecutamos la búsqueda con un identificador falso.
	if _, err := svc.Lookup(ctx, "F-00000"); !errors.Is(err, ErrReportNotFound) {
		t.Fatalf("expected ErrReportNotFound, got %v", err)
	}
}

func TestUpdateStatusReflectsOnMetrics(t *testing.T) {
	// 1.- Creamos un reporte inicial y cambiamos su estado a resuelto.
	repo := newFakeReportRepository()
	svc := NewReportService(repo, 1, 1)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	payload := map[string]any{
		"incidentTypeId": "trash",
		"description":    "Basura acumulada",
		"latitude":       19.4,
		"longitude":      -99.1,
	}
	created, err := svc.Submit(ctx, payload)
	if err != nil {
		t.Fatalf("Submit returned error: %v", err)
	}

	updated, err := svc.UpdateStatus(ctx, created.ID, "resuelto")
	if err != nil {
		t.Fatalf("UpdateStatus returned error: %v", err)
	}
	if updated.Status != "resuelto" {
		t.Fatalf("expected resuelto status, got %s", updated.Status)
	}

	// 2.- Confirmamos que los conteos reflejan el cambio transaccional.
	metrics, err := svc.DashboardMetrics(ctx)
	if err != nil {
		t.Fatalf("DashboardMetrics returned error: %v", err)
	}
	if metrics.ResolvedReports != 1 || metrics.PendingReports != 0 {
		t.Fatalf("unexpected metrics: %+v", metrics)
	}
}
