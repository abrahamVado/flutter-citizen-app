package httpserver

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"citizenapp/backend/internal/service"
)

// 1.- Server agrupa las dependencias y el ruteo HTTP.
type Server struct {
	authService    *service.AuthService
	catalogService *service.CatalogService
	reportService  *service.ReportService
}

// 2.- New construye el servidor y configura las rutas.
func New(auth *service.AuthService, catalog *service.CatalogService, reports *service.ReportService) *Server {
	return &Server{
		authService:    auth,
		catalogService: catalog,
		reportService:  reports,
	}
}

// 3.- Router expone el *chi.Mux con los handlers concurrentes.
func (s *Server) Router() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/auth", withMethod(http.MethodPost, s.handleAuth))
	mux.HandleFunc("/catalog", withMethod(http.MethodGet, s.handleCatalog))
	mux.HandleFunc("/reports", withMethod(http.MethodPost, s.handleReportSubmit))
	mux.HandleFunc("/folios/", withMethod(http.MethodGet, s.handleFolioLookup))
	return mux
}

func (s *Server) handleAuth(w http.ResponseWriter, r *http.Request) {
	// 4.- Creamos un contexto con tiempo de espera para el worker pool.
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	type credentials struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	var body credentials
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}
	resp, err := s.authService.Authenticate(ctx, body.Email, body.Password)
	if err != nil {
		http.Error(w, err.Error(), http.StatusGatewayTimeout)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) handleCatalog(w http.ResponseWriter, r *http.Request) {
	// 5.- Delegamos en el pool del catálogo para responder rápidamente.
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	catalog, err := s.catalogService.Fetch(ctx)
	if err != nil {
		http.Error(w, err.Error(), http.StatusGatewayTimeout)
		return
	}
	writeJSON(w, http.StatusOK, catalog)
}

func (s *Server) handleReportSubmit(w http.ResponseWriter, r *http.Request) {
	// 6.- Encolamos la creación de reportes dentro del worker dedicado.
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	var payload map[string]any
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}
	report, err := s.reportService.Submit(ctx, payload)
	if err != nil {
		http.Error(w, err.Error(), http.StatusGatewayTimeout)
		return
	}
	writeJSON(w, http.StatusCreated, report)
}

func (s *Server) handleFolioLookup(w http.ResponseWriter, r *http.Request) {
	// 7.- Consultamos los folios mediante el pool especializado.
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	folioID := strings.TrimPrefix(r.URL.Path, "/folios/")
	if folioID == "" {
		http.Error(w, "missing folio id", http.StatusBadRequest)
		return
	}
	status, err := s.reportService.Lookup(ctx, folioID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusGatewayTimeout)
		return
	}
	writeJSON(w, http.StatusOK, status)
}

// 8.- writeJSON centraliza la serialización y cabeceras comunes.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

// 9.- withMethod valida el método HTTP antes de delegar en el handler real.
func withMethod(method string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != method {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		next(w, r)
	}
}
