package httpgin

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

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
		c.String(http.StatusNotFound, "404 page not found\n")
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
	// 5.- Reutilizamos withMethod para preservar respuestas 405 personalizadas.
	s.engine.Any("/auth", withMethod(http.MethodPost, s.handleAuth))
	s.engine.Any("/catalog", withMethod(http.MethodGet, s.handleCatalog))
	s.engine.Any("/reports", withMethod(http.MethodPost, s.handleReportSubmit))
	s.engine.Any("/folios/*id", withMethod(http.MethodGet, s.handleFolioLookup))
	s.engine.Any("/ws", withMethod(http.MethodGet, s.handleWebSocket))
}

func (s *Server) handleAuth(c *gin.Context) {
	// 6.- Ejecutamos la autenticación con límite de tiempo en el pool.
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	type credentials struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	var body credentials
	if err := c.ShouldBindJSON(&body); err != nil {
		writeError(c, http.StatusBadRequest, "invalid payload")
		return
	}
	resp, err := s.authService.Authenticate(ctx, body.Email, body.Password)
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, resp)
}

func (s *Server) handleCatalog(c *gin.Context) {
	// 7.- Delegamos en el pool del catálogo para respuestas ágiles.
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()
	catalog, err := s.catalogService.Fetch(ctx)
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, catalog)
}

func (s *Server) handleReportSubmit(c *gin.Context) {
	// 8.- Encolamos el reporte y notificamos al hub en paralelo.
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()
	var payload map[string]any
	if err := c.ShouldBindJSON(&payload); err != nil {
		writeError(c, http.StatusBadRequest, "invalid payload")
		return
	}
	report, err := s.reportService.Submit(ctx, payload)
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	_ = s.realtimeHub.BroadcastReport(report)
	writeJSON(c, http.StatusCreated, report)
}

func (s *Server) handleFolioLookup(c *gin.Context) {
	// 9.- Validamos el folio y lo consultamos en el pool dedicado.
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()
	folioID := strings.TrimPrefix(c.Param("id"), "/")
	if folioID == "" {
		writeError(c, http.StatusBadRequest, "missing folio id")
		return
	}
	status, err := s.reportService.Lookup(ctx, folioID)
	if err != nil {
		writeError(c, http.StatusGatewayTimeout, err.Error())
		return
	}
	writeJSON(c, http.StatusOK, status)
}

// 10.- handleWebSocket conserva la actualización en tiempo real.
func (s *Server) handleWebSocket(c *gin.Context) {
	conn, err := s.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		writeError(c, http.StatusBadRequest, "websocket upgrade failed")
		return
	}
	client := s.realtimeHub.Register(conn)
	go client.Run(context.Background())
}

// 11.- Shutdown sincroniza el cierre del hub con el servidor HTTP.
func (s *Server) Shutdown(ctx context.Context) error {
	return s.realtimeHub.Shutdown(ctx)
}

// 12.- writeJSON homologa la serialización JSON y cabeceras comunes.
func writeJSON(c *gin.Context, status int, payload any) {
	c.Header("Content-Type", "application/json")
	c.Status(status)
	encoder := json.NewEncoder(c.Writer)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(payload)
}

// 13.- writeError replica el formato de http.Error con salto de línea.
func writeError(c *gin.Context, status int, message string) {
	c.Data(status, "text/plain; charset=utf-8", []byte(message+"\n"))
	c.Abort()
}

// 14.- withMethod mantiene la validación explícita de métodos HTTP.
func withMethod(method string, next gin.HandlerFunc) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method != method {
			writeError(c, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		next(c)
	}
}
