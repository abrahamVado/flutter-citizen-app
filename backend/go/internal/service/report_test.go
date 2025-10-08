package service

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"
)

func TestReportSubmitAndLookupLifecycle(t *testing.T) {
	// 1.- Configuramos el servicio de reportes con pools dedicados.
	svc := NewReportService(2, 2)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// 2.- Enviamos un reporte mínimo y validamos la respuesta generada.
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

	// 3.- Consultamos el mismo folio y verificamos el historial simulado.
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
	svc := NewReportService(1, 1)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	// 2.- Ejecutamos la búsqueda con un identificador falso.
	if _, err := svc.Lookup(ctx, "F-00000"); !errors.Is(err, ErrReportNotFound) {
		t.Fatalf("expected ErrReportNotFound, got %v", err)
	}
}
