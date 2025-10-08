package httpserver

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"citizenapp/backend/internal/service"
)

func TestRouterEndpoints(t *testing.T) {
	// 1.- Construimos el servidor con servicios reales en memoria.
	authSvc := service.NewAuthService(1, time.Minute)
	catalogSvc := service.NewCatalogService(1)
	reportSvc := service.NewReportService(1, 1)
	srv := New(authSvc, catalogSvc, reportSvc)
	defer srv.Shutdown(context.Background())
	client := srv.realtimeHub.Register(&captureConn{})
	handler := srv.Router()
	ts := httptest.NewServer(handler)
	defer ts.Close()

	// 2.- Validamos el endpoint de autenticación.
	authBody, _ := json.Marshal(map[string]string{"email": "user@demo.com", "password": "pass"})
	resp, err := http.Post(ts.URL+"/auth", "application/json", bytes.NewReader(authBody))
	if err != nil {
		t.Fatalf("auth request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("unexpected auth status: %d", resp.StatusCode)
	}
	_ = resp.Body.Close()

	// 3.- Consultamos el catálogo asegurando la respuesta exitosa.
	resp, err = http.Get(ts.URL + "/catalog")
	if err != nil {
		t.Fatalf("catalog request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("unexpected catalog status: %d", resp.StatusCode)
	}
	_ = resp.Body.Close()

	// 4.- Enviamos un reporte, revisamos el folio y esperamos el broadcast.
	reportBody, _ := json.Marshal(map[string]any{
		"incidentTypeId": "pothole",
		"description":    "Alcantarilla sin tapa",
		"latitude":       19.4,
		"longitude":      -99.1,
	})
	resp, err = http.Post(ts.URL+"/reports", "application/json", bytes.NewReader(reportBody))
	if err != nil {
		t.Fatalf("report request failed: %v", err)
	}
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("unexpected report status: %d", resp.StatusCode)
	}
	var submitted service.Report
	if err := json.NewDecoder(resp.Body).Decode(&submitted); err != nil {
		t.Fatalf("cannot decode report: %v", err)
	}
	_ = resp.Body.Close()
	if submitted.ID == "" {
		t.Fatalf("expected folio in report response")
	}
	select {
	case message := <-client.Messages():
		var broadcast map[string]any
		if err := json.Unmarshal(message, &broadcast); err != nil {
			t.Fatalf("cannot decode broadcast: %v", err)
		}
		if broadcast["type"] != "report.created" {
			t.Fatalf("unexpected broadcast type: %v", broadcast["type"])
		}
	case <-time.After(2 * time.Second):
		t.Fatalf("expected broadcast message for new report")
	}

	// 5.- Recuperamos el folio mediante el endpoint dedicado.
	lookupResp, err := http.Get(ts.URL + "/folios/" + submitted.ID)
	if err != nil {
		t.Fatalf("lookup request failed: %v", err)
	}
	if lookupResp.StatusCode != http.StatusOK {
		t.Fatalf("unexpected lookup status: %d", lookupResp.StatusCode)
	}
	var status service.FolioStatus
	if err := json.NewDecoder(lookupResp.Body).Decode(&status); err != nil {
		t.Fatalf("cannot decode lookup response: %v", err)
	}
	_ = lookupResp.Body.Close()
	if status.Folio != submitted.ID {
		t.Fatalf("folio mismatch: %s vs %s", status.Folio, submitted.ID)
	}
}

func TestRouterTimeoutsPropagate(t *testing.T) {
	// 1.- Creamos un contexto que vence inmediatamente para el servicio de autenticación.
	authSvc := service.NewAuthService(1, time.Minute)
	catalogSvc := service.NewCatalogService(1)
	reportSvc := service.NewReportService(1, 1)
	srv := New(authSvc, catalogSvc, reportSvc)
	defer srv.Shutdown(context.Background())

	// 2.- Ejecutamos el handler con un contexto cancelado y verificamos el error.
	req := httptest.NewRequest(http.MethodPost, "/auth", bytes.NewReader([]byte("{}")))
	ctx, cancel := context.WithCancel(req.Context())
	cancel()
	req = req.WithContext(ctx)
	rr := httptest.NewRecorder()
	srv.handleAuth(rr, req)
	if rr.Code != http.StatusBadRequest && rr.Code != http.StatusGatewayTimeout {
		t.Fatalf("expected early termination status, got %d", rr.Code)
	}
}

// 3.- captureConn simula una conexión de WebSocket sin realizar IO real.
type captureConn struct {
	closed atomic.Bool
}

func (c *captureConn) SetReadLimit(int64)                        {}
func (c *captureConn) SetReadDeadline(time.Time) error           { return nil }
func (c *captureConn) SetWriteDeadline(time.Time) error          { return nil }
func (c *captureConn) SetPongHandler(func(string) error)         {}
func (c *captureConn) ReadMessage() (int, []byte, error)         { return 0, nil, context.Canceled }
func (c *captureConn) WriteMessage(int, []byte) error            { return nil }
func (c *captureConn) WriteControl(int, []byte, time.Time) error { return nil }
func (c *captureConn) Close() error {
	c.closed.Store(true)
	return nil
}
