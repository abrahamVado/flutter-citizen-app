package httpgin

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"citizenapp/backend/internal/service"
	"github.com/gin-gonic/gin"
)

func TestReportSubmissionFlow(t *testing.T) {
	// 1.- Configuramos Gin en modo de pruebas para minimizar el ruido.
	gin.SetMode(gin.TestMode)
	authSvc := service.NewAuthService(1, time.Minute)
	catalogSvc := service.NewCatalogService(1)
	reportSvc := service.NewReportService(1, 1)
	srv := New(authSvc, catalogSvc, reportSvc)
	defer srv.Shutdown(context.Background())

	// 2.- Registramos un cliente simulado para capturar el broadcast del hub.
	client := srv.realtimeHub.Register(&captureConn{})
	// 3.- Enviamos un reporte válido contra el engine y verificamos el código 201.
	payload := map[string]any{
		"incidentTypeId": "pothole",
		"description":    "Alcantarilla sin tapa",
		"latitude":       19.4,
		"longitude":      -99.1,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("cannot marshal payload: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/reports", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	srv.Engine().ServeHTTP(rr, req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", rr.Code)
	}
	t.Log("report handler responded")
	var submitted service.Report
	if err := json.NewDecoder(rr.Body).Decode(&submitted); err != nil {
		t.Fatalf("cannot decode response: %v", err)
	}
	if submitted.ID == "" {
		t.Fatalf("expected generated folio identifier")
	}

	t.Log("decoded report, waiting for broadcast")

	// 4.- Aseguramos que el hub transmita el mensaje de creación del reporte.
	select {
	case msg := <-client.Messages():
		var broadcast map[string]any
		if err := json.Unmarshal(msg, &broadcast); err != nil {
			t.Fatalf("cannot decode broadcast: %v", err)
		}
		if broadcast["type"] != "report.created" {
			t.Fatalf("unexpected broadcast type: %v", broadcast["type"])
		}
		t.Log("received broadcast")
	case <-time.After(2 * time.Second):
		t.Fatalf("expected broadcast after report submission")
	}
}

func TestMethodEnforcement(t *testing.T) {
	// 1.- Creamos el servidor y emitimos una solicitud con método incorrecto.
	gin.SetMode(gin.TestMode)
	authSvc := service.NewAuthService(1, time.Minute)
	catalogSvc := service.NewCatalogService(1)
	reportSvc := service.NewReportService(1, 1)
	srv := New(authSvc, catalogSvc, reportSvc)
	defer srv.Shutdown(context.Background())

	req := httptest.NewRequest(http.MethodGet, "/auth", nil)
	rr := httptest.NewRecorder()
	srv.Engine().ServeHTTP(rr, req)

	if rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status 405, got %d", rr.Code)
	}
	if body := rr.Body.String(); body != "method not allowed\n" {
		t.Fatalf("unexpected body: %q", body)
	}
}

// 3.- captureConn implementa la interfaz WebSocket mínima para pruebas.
type captureConn struct{}

func (c *captureConn) SetReadLimit(int64)                        {}
func (c *captureConn) SetReadDeadline(time.Time) error           { return nil }
func (c *captureConn) SetWriteDeadline(time.Time) error          { return nil }
func (c *captureConn) SetPongHandler(func(string) error)         {}
func (c *captureConn) ReadMessage() (int, []byte, error)         { return 0, nil, context.Canceled }
func (c *captureConn) WriteMessage(int, []byte) error            { return nil }
func (c *captureConn) WriteControl(int, []byte, time.Time) error { return nil }
func (c *captureConn) Close() error                              { return nil }
