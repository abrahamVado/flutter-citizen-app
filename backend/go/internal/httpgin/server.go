package httpgin

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"citizenapp/backend/internal/httpgin/dto"
	"citizenapp/backend/internal/realtime"
	"citizenapp/backend/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// 1.- Server agrupa los servicios, el motor Gin y el hub WebSocket.
type Server struct {
	authService    *service.AuthService
	catalogService *service.CatalogService
	reportService  *service.ReportService
	realtimeHub    *realtime.Hub
	upgrader       websocket.Upgrader
	engine         *gin.Engine
}

// 2.- New construye el servidor, configura Gin y prepara las rutas.
func New(auth *service.AuthService, catalog *service.CatalogService, reports *service.ReportService) *Server {
	if gin.Mode() == gin.DebugMode {
		gin.SetMode(gin.ReleaseMode)
	}
	engine := gin.New()
	engine.Use(gin.Logger(), gin.Recovery())
	engine.NoRoute(func(c *gin.Context) {
		writeError(c, http.StatusNotFound, "not found")
	})
	hub := realtime.NewHub(8, 8, 4096, 128)
	srv := &Server{
		authService:    auth,
		catalogService: catalog,
		reportService:  reports,
		realtimeHub:    hub,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
		},
		engine: engine,
	}
	srv.registerRoutes()
	return srv
}

// 3.- Router expone el motor Gin para integrarse con net/http.
func (s *Server) Router() http.Handler {
	return s.engine
}

// 4.- Engine devuelve el *gin.Engine interno para pruebas específicas.
func (s *Server) Engine() *gin.Engine {
	return s.engine
}

func (s *Server) registerRoutes() {
	// 5.- Agrupamos las rutas bajo /api/v1 para reflejar el contrato OpenAPI.
	api := s.engine.Group("/api/v1")
	s.registerEndpoint(api, "/auth/login", map[string]gin.HandlerFunc{
		http.MethodPost: s.handleAuthLogin,
	})
	s.registerEndpoint(api, "/auth/register", map[string]gin.HandlerFunc{
		http.MethodPost: s.handleAuthRegister,
	})
	s.registerEndpoint(api, "/auth/recover", map[string]gin.HandlerFunc{
		http.MethodPost: s.handleAuthRecover,
	})
	s.registerEndpoint(api, "/auth/social/:provider", map[string]gin.HandlerFunc{
		http.MethodPost: s.handleAuthSocial,
	})
	s.registerEndpoint(api, "/catalog/incident-types", map[string]gin.HandlerFunc{
		http.MethodGet: s.handleCatalog,
	})
	protected := api.Group("")
	protected.Use(s.requireAuth())
	s.registerEndpoint(protected, "/reports", map[string]gin.HandlerFunc{
		http.MethodGet:  s.handleReportList,
		http.MethodPost: s.handleReportSubmit,
	})
	s.registerEndpoint(protected, "/reports/:id", map[string]gin.HandlerFunc{
		http.MethodGet:    s.handleReportGet,
		http.MethodPatch:  s.handleReportUpdate,
		http.MethodDelete: s.handleReportDelete,
	})
	s.registerEndpoint(api, "/folios/:folio", map[string]gin.HandlerFunc{
		http.MethodGet: s.handleFolioLookup,
	})
	s.registerEndpoint(protected, "/admin/dashboard/metrics", map[string]gin.HandlerFunc{
		http.MethodGet: s.handleAdminMetrics,
	})
	s.engine.Handle(http.MethodGet, "/ws", func(c *gin.Context) {
		if c.Request.Method != http.MethodGet {
			writeError(c, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		s.handleWebSocket(c)
	})
}

// 6.- registerEndpoint controla métodos permitidos y devuelve 405 en caso contrario.
func (s *Server) registerEndpoint(group *gin.RouterGroup, path string, handlers map[string]gin.HandlerFunc) {
	group.Any(path, func(c *gin.Context) {
		if handler, ok := handlers[c.Request.Method]; ok {
			handler(c)
			return
		}
		writeError(c, http.StatusMethodNotAllowed, "method not allowed")
	})
}

// 7.- requireAuth valida el encabezado Bearer y aborta si el token no es válido.
func (s *Server) requireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			writeError(c, http.StatusUnauthorized, "missing bearer token")
			c.Abort()
			return
		}
		subject, err := s.authService.ValidateToken(strings.TrimSpace(parts[1]))
		if err != nil {
			writeError(c, http.StatusUnauthorized, err.Error())
			c.Abort()
			return
		}
		c.Set("auth.subject", subject)
		c.Next()
	}
}

// 8.- handleAuthLogin verifica credenciales y responde con token JWT.
func (s *Server) handleAuthLogin(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	var body dto.AuthCredentials
	if ok := decodeAndValidate(c, &body); !ok {
		return
	}
	resp, err := s.authService.Authenticate(ctx, body.Email, body.Password)
	if err != nil {
		status := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrInvalidCredentials) {
			status = http.StatusUnauthorized
		}
		writeError(c, status, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, resp)
}

// 9.- handleAuthRegister crea un usuario y retorna el token inicial.
func (s *Server) handleAuthRegister(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	var body dto.AuthCredentials
	if ok := decodeAndValidate(c, &body); !ok {
		return
	}
	resp, err := s.authService.Register(ctx, body.Email, body.Password)
	if err != nil {
		status := http.StatusGatewayTimeout
		switch {
		case errors.Is(err, service.ErrInvalidCredentials):
			status = http.StatusBadRequest
		case errors.Is(err, service.ErrEmailConflict):
			status = http.StatusConflict
		}
		writeError(c, status, err.Error())
		return
	}
	writeJSON(c, http.StatusCreated, resp)
}

// 10.- handleAuthRecover confirma la existencia y simula el envío de correo.
func (s *Server) handleAuthRecover(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	var body dto.RecoverRequest
	if ok := decodeAndValidate(c, &body); !ok {
		return
	}
	if err := s.authService.Recover(ctx, body.Email); err != nil {
		status := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrInvalidCredentials) {
			status = http.StatusBadRequest
		}
		writeError(c, status, err.Error())
		return
	}
	c.Status(http.StatusAccepted)
}

// 11.- handleAuthSocial valida el proveedor y responde con token federado.
func (s *Server) handleAuthSocial(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	provider := c.Param("provider")
	resp, err := s.authService.SocialAuthenticate(ctx, provider)
	if err != nil {
		status := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrUnsupportedLogin) {
			status = http.StatusBadRequest
		}
		writeError(c, status, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, resp)
}

// 12.- handleCatalog delega al servicio para obtener los tipos de incidentes.
func (s *Server) handleCatalog(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	catalog, err := s.catalogService.Fetch(ctx)
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, catalog)
}

// 13.- handleReportList atiende las solicitudes paginadas del panel.
func (s *Server) handleReportList(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	page := parseQueryInt(c.Query("page"), 0)
	pageSize := parseQueryInt(c.Query("pageSize"), 20)
	status := c.Query("status")
	reports, err := s.reportService.List(ctx, page, pageSize, status)
	if err != nil {
		statusCode := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrInvalidStatus) {
			statusCode = http.StatusBadRequest
		}
		writeError(c, statusCode, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, reports)
}

// 14.- handleReportSubmit recibe el reporte ciudadano y notifica al hub.
func (s *Server) handleReportSubmit(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()
	var payload dto.ReportSubmissionRequest
	if ok := decodeAndValidate(c, &payload); !ok {
		return
	}
	report, err := s.reportService.Submit(ctx, payload.ToPayload())
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	_ = s.realtimeHub.BroadcastReport(report)
	writeJSON(c, http.StatusCreated, report)
}

// 15.- handleReportGet devuelve el detalle puntual del reporte.
func (s *Server) handleReportGet(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	id := c.Param("id")
	report, err := s.reportService.Get(ctx, id)
	if err != nil {
		status := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrReportNotFound) {
			status = http.StatusNotFound
		}
		writeError(c, status, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, report)
}

// 16.- handleReportUpdate permite cambiar el estatus del reporte.
func (s *Server) handleReportUpdate(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	id := c.Param("id")
	var body dto.ReportStatusUpdateRequest
	if ok := decodeAndValidate(c, &body); !ok {
		return
	}
	report, err := s.reportService.UpdateStatus(ctx, id, body.Status)
	if err != nil {
		status := http.StatusGatewayTimeout
		switch {
		case errors.Is(err, service.ErrInvalidStatus):
			status = http.StatusBadRequest
		case errors.Is(err, service.ErrReportNotFound):
			status = http.StatusNotFound
		}
		writeError(c, status, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, report)
}

// 17.- handleReportDelete elimina definitivamente el registro.
func (s *Server) handleReportDelete(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	id := c.Param("id")
	if err := s.reportService.Delete(ctx, id); err != nil {
		status := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrReportNotFound) {
			status = http.StatusNotFound
		}
		writeError(c, status, err.Error())
		return
	}
	c.Status(http.StatusNoContent)
}

// 18.- handleFolioLookup reutiliza el servicio para mostrar el seguimiento.
func (s *Server) handleFolioLookup(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	folioID := c.Param("folio")
	if strings.TrimSpace(folioID) == "" {
		writeError(c, http.StatusBadRequest, "missing folio id")
		return
	}
	status, err := s.reportService.Lookup(ctx, folioID)
	if err != nil {
		statusCode := http.StatusGatewayTimeout
		if errors.Is(err, service.ErrReportNotFound) {
			statusCode = http.StatusNotFound
		}
		writeError(c, statusCode, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, status)
}

// 19.- handleAdminMetrics calcula los totales requeridos por el dashboard.
func (s *Server) handleAdminMetrics(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	metrics, err := s.reportService.DashboardMetrics(ctx)
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, metrics)
}

// 20.- handleWebSocket conserva la actualización en tiempo real.
func (s *Server) handleWebSocket(c *gin.Context) {
	conn, err := s.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		writeError(c, http.StatusBadRequest, "websocket upgrade failed")
		return
	}
	client := s.realtimeHub.Register(conn)
	go client.Run(context.Background())
}

// 21.- Shutdown sincroniza el cierre del hub con el servidor HTTP.
func (s *Server) Shutdown(ctx context.Context) error {
	return s.realtimeHub.Shutdown(ctx)
}

// 22.- writeJSON homologa la serialización JSON y cabeceras comunes.
func writeJSON(c *gin.Context, status int, payload any) {
	c.Header("Content-Type", "application/json")
	c.Status(status)
	encoder := json.NewEncoder(c.Writer)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(payload)
}

// 23.- writeError devuelve el esquema de ErrorResponse definido en OpenAPI.
func writeError(c *gin.Context, status int, message string) {
	type errorResponse struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	}
	payload := errorResponse{Code: status, Message: message}
	c.AbortWithStatusJSON(status, payload)
}

// 24.- parseQueryInt estandariza la conversión de parámetros numéricos.
func parseQueryInt(raw string, fallback int) int {
	if strings.TrimSpace(raw) == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return value
}
