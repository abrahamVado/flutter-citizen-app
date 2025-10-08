package httpgin

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"citizenapp/backend/internal/service"
	"github.com/gin-gonic/gin"
)

// 1.- inMemoryUserRepository simula la base de datos para autenticación.
type inMemoryUserRepository struct {
	mu    sync.RWMutex
	users map[string]string
}

func newInMemoryUserRepository() *inMemoryUserRepository {
	return &inMemoryUserRepository{users: make(map[string]string)}
}

func (r *inMemoryUserRepository) Create(_ context.Context, email, passwordHash string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, exists := r.users[email]; exists {
		return service.ErrEmailConflict
	}
	r.users[email] = passwordHash
	return nil
}

func (r *inMemoryUserRepository) PasswordHash(_ context.Context, email string) (string, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	hash, ok := r.users[email]
	if !ok {
		return "", service.ErrInvalidCredentials
	}
	return hash, nil
}

func (r *inMemoryUserRepository) Exists(_ context.Context, email string) (bool, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	_, ok := r.users[email]
	return ok, nil
}

// 2.- inMemoryReportRepository replica service.ReportRepository en memoria.
type inMemoryReportRepository struct {
	mu      sync.RWMutex
	records map[string]service.Report
}

func newInMemoryReportRepository() *inMemoryReportRepository {
	return &inMemoryReportRepository{records: make(map[string]service.Report)}
}

func (r *inMemoryReportRepository) Create(_ context.Context, report service.Report) (service.Report, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.records[report.ID] = report
	return report, nil
}

func (r *inMemoryReportRepository) FindByID(_ context.Context, id string) (service.Report, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	report, ok := r.records[id]
	if !ok {
		return service.Report{}, service.ErrReportNotFound
	}
	return report, nil
}

func (r *inMemoryReportRepository) List(_ context.Context, page, pageSize int, status string) ([]service.Report, int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	items := make([]service.Report, 0, len(r.records))
	for _, report := range r.records {
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

func (r *inMemoryReportRepository) Delete(_ context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.records[id]; !ok {
		return service.ErrReportNotFound
	}
	delete(r.records, id)
	return nil
}

func (r *inMemoryReportRepository) Lookup(ctx context.Context, id string) (service.FolioStatus, error) {
	report, err := r.FindByID(ctx, id)
	if err != nil {
		return service.FolioStatus{}, err
	}
	return service.FolioStatus{
		Folio:      report.ID,
		Status:     report.Status,
		LastUpdate: time.Now(),
		History:    []string{"Reporte recibido", "Asignado a cuadrilla"},
	}, nil
}

func (r *inMemoryReportRepository) UpdateStatusWithMetrics(ctx context.Context, id, status string) (service.Report, service.AdminDashboardMetrics, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	report, ok := r.records[id]
	if !ok {
		return service.Report{}, service.AdminDashboardMetrics{}, service.ErrReportNotFound
	}
	report.Status = status
	r.records[id] = report
	metrics := r.metricsLocked()
	return report, metrics, nil
}

func (r *inMemoryReportRepository) Metrics(_ context.Context) (service.AdminDashboardMetrics, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.metricsLocked(), nil
}

func (r *inMemoryReportRepository) metricsLocked() service.AdminDashboardMetrics {
	metrics := service.AdminDashboardMetrics{}
	for _, report := range r.records {
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

// 3.- buildServer centraliza la creación del servidor de pruebas.
func buildServer(t *testing.T) *Server {
	t.Helper()
	gin.SetMode(gin.TestMode)
	authRepo := newInMemoryUserRepository()
	reportRepo := newInMemoryReportRepository()
	authSvc := service.NewAuthService(authRepo, 2, time.Minute, []byte("integration-secret"))
	catalogSvc := service.NewCatalogService(1)
	reportSvc := service.NewReportService(reportRepo, 2, 2)
	srv := New(authSvc, catalogSvc, reportSvc)
	t.Cleanup(func() {
		_ = srv.Shutdown(context.Background())
	})
	return srv
}

func TestOpenAPIEndpointsHappyPath(t *testing.T) {
	// 4.- Iniciamos el servidor y registramos un usuario nuevo.
	srv := buildServer(t)
	registerBody := map[string]string{
		"email":    "citizen@example.com",
		"password": "ClaveSegura1",
	}
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/register", registerBody, http.StatusCreated, nil)

	// 5.- Validamos el login tradicional.
	var loginResponse service.AuthResponse
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/login", registerBody, http.StatusOK, &loginResponse)
	if loginResponse.Token == "" {
		t.Fatalf("expected non-empty token from login")
	}
	authHeader := withAuth(loginResponse.Token)

	// 6.- Recuperación de contraseña debe confirmar la cuenta.
	recoverBody := map[string]string{"email": registerBody["email"]}
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/recover", recoverBody, http.StatusAccepted, nil)

	// 7.- Autenticación social valida proveedores soportados.
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/social/google", map[string]string{}, http.StatusOK, nil)

	// 8.- El catálogo debe responder con tipos disponibles.
	var catalog []service.IncidentType
	performRequest(t, srv, http.MethodGet, "/api/v1/catalog/incident-types", nil, http.StatusOK, &catalog)
	if len(catalog) == 0 {
		t.Fatalf("expected at least one incident type")
	}

	// 9.- Capturamos el hub para verificar el broadcast posterior.
	client := srv.realtimeHub.Register(&captureConn{})

	// 10.- Ingresamos un reporte completo.
	reportBody := map[string]any{
		"incidentTypeId": "pothole",
		"description":    "Bache profundo",
		"contactEmail":   registerBody["email"],
		"contactPhone":   "5512345678",
		"latitude":       19.4,
		"longitude":      -99.1,
		"address":        "Centro, CDMX",
	}
	var created service.Report
	performJSON(t, srv, http.MethodPost, "/api/v1/reports", reportBody, http.StatusCreated, &created, authHeader)
	if created.ID == "" {
		t.Fatalf("expected generated report identifier")
	}

	// 11.- Confirmamos la notificación WebSocket del nuevo reporte.
	select {
	case msg := <-client.Messages():
		var payload map[string]any
		if err := json.Unmarshal(msg, &payload); err != nil {
			t.Fatalf("cannot decode broadcast: %v", err)
		}
		if payload["type"] != "report.created" {
			t.Fatalf("unexpected broadcast type: %v", payload["type"])
		}
	case <-time.After(2 * time.Second):
		t.Fatalf("expected websocket broadcast after submission")
	}

	// 12.- Listamos los reportes administrativos.
	var list service.PaginatedReports
	performRequest(t, srv, http.MethodGet, "/api/v1/reports?page=0&pageSize=10", nil, http.StatusOK, &list, authHeader)
	if len(list.Items) == 0 {
		t.Fatalf("expected paginated items in list endpoint")
	}

	// 13.- Leemos el reporte directo y comprobamos el ID.
	var fetched service.Report
	performRequest(t, srv, http.MethodGet, "/api/v1/reports/"+created.ID, nil, http.StatusOK, &fetched, authHeader)
	if fetched.ID != created.ID {
		t.Fatalf("expected fetched report ID %s, got %s", created.ID, fetched.ID)
	}

	// 14.- Actualizamos el estatus a resuelto.
	updateBody := map[string]string{"status": "resuelto"}
	performJSON(t, srv, http.MethodPatch, "/api/v1/reports/"+created.ID, updateBody, http.StatusOK, &fetched, authHeader)
	if fetched.Status != "resuelto" {
		t.Fatalf("expected updated status resuelto, got %s", fetched.Status)
	}

	// 15.- El dashboard debe reflejar el conteo de resueltos.
	var metrics service.AdminDashboardMetrics
	performRequest(t, srv, http.MethodGet, "/api/v1/admin/dashboard/metrics", nil, http.StatusOK, &metrics, authHeader)
	if metrics.ResolvedReports == 0 {
		t.Fatalf("expected resolved reports metric to be positive")
	}

	// 16.- Consultamos el folio directo para validar seguimiento.
	var folio service.FolioStatus
	performRequest(t, srv, http.MethodGet, "/api/v1/folios/"+created.ID, nil, http.StatusOK, &folio)
	if folio.Folio != created.ID {
		t.Fatalf("expected folio %s, got %s", created.ID, folio.Folio)
	}

	// 17.- Eliminamos el reporte y comprobamos la ausencia posterior.
	performRequest(t, srv, http.MethodDelete, "/api/v1/reports/"+created.ID, nil, http.StatusNoContent, nil, authHeader)
	performRequest(t, srv, http.MethodGet, "/api/v1/reports/"+created.ID, nil, http.StatusNotFound, nil, authHeader)
}

func TestMethodEnforcementRemainsActive(t *testing.T) {
	// 18.- Un GET sobre login debe seguir devolviendo 405.
	srv := buildServer(t)
	performRequest(t, srv, http.MethodGet, "/api/v1/auth/login", nil, http.StatusMethodNotAllowed, nil)
}

func TestProtectedEndpointsRequireToken(t *testing.T) {
	// 19.- Las rutas protegidas deben rechazar la ausencia de token.
	srv := buildServer(t)
	performRequest(t, srv, http.MethodGet, "/api/v1/reports", nil, http.StatusUnauthorized, nil)

	// 20.- Un token inválido también regresa 401.
	performRequest(t, srv, http.MethodGet, "/api/v1/reports", nil, http.StatusUnauthorized, nil, withAuth("malformed"))
}

func TestReportSubmissionValidationRejectsMalformedPayload(t *testing.T) {
	// 21.- El validador debe prevenir que cargas incompletas lleguen al servicio.
	srv := buildServer(t)
	credentials := map[string]string{
		"email":    "validator@example.com",
		"password": "ClaveSegura1",
	}
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/register", credentials, http.StatusCreated, nil)
	var token service.AuthResponse
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/login", credentials, http.StatusOK, &token)
	invalidReport := map[string]any{
		"incidentTypeId": "",
		"description":    "",
		"contactEmail":   "no-es-correo",
		"contactPhone":   "123",
		"latitude":       120.0,
		"longitude":      200.0,
		"address":        "",
	}
	performJSON(t, srv, http.MethodPost, "/api/v1/reports", invalidReport, http.StatusBadRequest, nil, withAuth(token.Token))
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	reports, err := srv.reportService.List(ctx, 0, 10, "")
	if err != nil {
		t.Fatalf("unexpected list error: %v", err)
	}
	if len(reports.Items) != 0 {
		t.Fatalf("expected zero reports after invalid submission, got %d", len(reports.Items))
	}
}

func TestMetricsEndpointReportsObservability(t *testing.T) {
	// 22.- El endpoint /metrics debe exponer las métricas clave instrumentadas.
	srv := buildServer(t)
	creds := map[string]string{
		"email":    "metrics@example.com",
		"password": "ClaveSegura1",
	}
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/register", creds, http.StatusCreated, nil)
	var login service.AuthResponse
	performJSON(t, srv, http.MethodPost, "/api/v1/auth/login", creds, http.StatusOK, &login)
	submission := map[string]any{
		"incidentTypeId": "flood",
		"description":    "Avenida inundada",
		"contactEmail":   creds["email"],
		"contactPhone":   "5587654321",
		"latitude":       19.43,
		"longitude":      -99.13,
		"address":        "Centro",
	}
	performJSON(t, srv, http.MethodPost, "/api/v1/reports", submission, http.StatusCreated, nil, withAuth(login.Token))
	time.Sleep(150 * time.Millisecond)
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rr := httptest.NewRecorder()
	srv.Router().ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200 from metrics endpoint, got %d", rr.Code)
	}
	body := rr.Body.String()
	if !strings.Contains(body, "citizenapp_report_submit_queue_depth") {
		t.Fatalf("expected submit queue metric in body, got %s", body)
	}
	if !strings.Contains(body, "citizenapp_http_request_duration_seconds_bucket") {
		t.Fatalf("expected http duration histogram in body, got %s", body)
	}
	if !strings.Contains(body, "citizenapp_realtime_broadcast_latency_seconds_bucket") {
		t.Fatalf("expected broadcast latency histogram in body, got %s", body)
	}
}

// 23.- performJSON ayuda a serializar cuerpos y decodificar respuestas.
func performJSON(t *testing.T, srv *Server, method, path string, payload any, expected int, target any, opts ...func(*http.Request)) {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("cannot marshal payload: %v", err)
	}
	performWithBody(t, srv, method, path, bytes.NewReader(body), expected, target, opts...)
}

// 24.- performRequest ejecuta solicitudes sin cuerpo auxiliar.
func performRequest(t *testing.T, srv *Server, method, path string, body *bytes.Reader, expected int, target any, opts ...func(*http.Request)) {
	t.Helper()
	var reader *bytes.Reader
	if body != nil {
		reader = body
	} else {
		reader = bytes.NewReader(nil)
	}
	performWithBody(t, srv, method, path, reader, expected, target, opts...)
}

// 25.- performWithBody centraliza la ejecución contra el engine Gin.
func performWithBody(t *testing.T, srv *Server, method, path string, reader *bytes.Reader, expected int, target any, opts ...func(*http.Request)) {
	t.Helper()
	req := httptest.NewRequest(method, path, reader)
	if method == http.MethodPost || method == http.MethodPatch {
		req.Header.Set("Content-Type", "application/json")
	}
	for _, opt := range opts {
		opt(req)
	}
	rr := httptest.NewRecorder()
	srv.Engine().ServeHTTP(rr, req)
	if rr.Code != expected {
		t.Fatalf("expected status %d for %s %s, got %d with body %s", expected, method, path, rr.Code, rr.Body.String())
	}
	if target != nil && rr.Body.Len() > 0 {
		if err := json.Unmarshal(rr.Body.Bytes(), target); err != nil {
			t.Fatalf("cannot decode response: %v", err)
		}
	}
}

// 26.- withAuth adjunta el encabezado Authorization requerido por las rutas.
func withAuth(token string) func(*http.Request) {
	return func(r *http.Request) {
		r.Header.Set("Authorization", "Bearer "+token)
	}
}

// 27.- captureConn implementa la interfaz WebSocket mínima para pruebas.
type captureConn struct{}

func (c *captureConn) SetReadLimit(int64)                        {}
func (c *captureConn) SetReadDeadline(time.Time) error           { return nil }
func (c *captureConn) SetWriteDeadline(time.Time) error          { return nil }
func (c *captureConn) SetPongHandler(func(string) error)         {}
func (c *captureConn) ReadMessage() (int, []byte, error)         { return 0, nil, context.Canceled }
func (c *captureConn) WriteMessage(int, []byte) error            { return nil }
func (c *captureConn) WriteControl(int, []byte, time.Time) error { return nil }
func (c *captureConn) Close() error                              { return nil }
