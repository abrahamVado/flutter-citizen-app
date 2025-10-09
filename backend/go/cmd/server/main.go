package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	httpserver "citizenapp/backend/internal/httpgin"
	"citizenapp/backend/internal/repository"
	"citizenapp/backend/internal/service"
	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	// 1.- Abrimos la conexión a PostgreSQL para repositorios compartidos.
	dsn := os.Getenv("DATABASE_URL")
	if strings.TrimSpace(dsn) == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		log.Fatalf("cannot open database: %v", err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		log.Fatalf("cannot reach database: %v", err)
	}

	// 2.- Extraemos la clave JWT requerida para firmar tokens.
	jwtSecret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
	if jwtSecret == "" {
		log.Fatal("JWT_SECRET environment variable is required")
	}

	// 3.- Inicializamos los servicios concurrentes requeridos por el API.
	userRepo := repository.NewPostgresUserRepository(db)
	reportRepo := repository.NewPostgresReportRepository(db)
	authService := service.NewAuthService(userRepo, 4, 8*time.Hour, []byte(jwtSecret))
	catalogService := service.NewCatalogService(2)
	reportService := service.NewReportService(reportRepo, 4, 4)

	// 4.- Leemos configuración HTTP (TLS, rate limiting y llaves) desde entorno.
	httpConfig := httpserver.DefaultConfig()
	httpConfig.RequireTLS = envBool("HTTP_REQUIRE_TLS", httpConfig.RequireTLS)
	httpConfig.MetricsAPIKey = strings.TrimSpace(os.Getenv("ADMIN_METRICS_API_KEY"))
	httpConfig.RateLimits.AuthRequests = envInt("RATE_LIMIT_AUTH_REQUESTS", httpConfig.RateLimits.AuthRequests)
	httpConfig.RateLimits.ReportRequests = envInt("RATE_LIMIT_REPORT_REQUESTS", httpConfig.RateLimits.ReportRequests)
	httpConfig.RateLimits.AuthWindow = envDuration("RATE_LIMIT_AUTH_WINDOW", httpConfig.RateLimits.AuthWindow)
	httpConfig.RateLimits.ReportWindow = envDuration("RATE_LIMIT_REPORT_WINDOW", httpConfig.RateLimits.ReportWindow)

	// 5.- Construimos el enrutador HTTP basado en los servicios previos.
	srv := httpserver.New(authService, catalogService, reportService, httpConfig)
	handler := srv.Router()

	// 6.- Configuramos el servidor tomando el puerto del entorno si existe.
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      handler,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  30 * time.Second,
	}

	go func() {
		log.Printf("backend listening on %s", server.Addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	// 7.- Manejamos la terminación elegante ante señales del sistema.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("shutdown error: %v", err)
	}
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("realtime shutdown error: %v", err)
	}
}

// 8.- envBool convierte variables booleanas conservando defaults seguros.
func envBool(key string, fallback bool) bool {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	value, err := strconv.ParseBool(raw)
	if err != nil {
		log.Printf("invalid boolean for %s=%q, keeping default %t", key, raw, fallback)
		return fallback
	}
	return value
}

// 9.- envInt garantiza enteros positivos para límites de solicitudes.
func envInt(key string, fallback int) int {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		log.Printf("invalid integer for %s=%q, keeping default %d", key, raw, fallback)
		return fallback
	}
	return value
}

// 10.- envDuration interpreta ventanas tipo 30s, 1m y regresa fallback si fallan.
func envDuration(key string, fallback time.Duration) time.Duration {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	value, err := time.ParseDuration(raw)
	if err != nil || value <= 0 {
		log.Printf("invalid duration for %s=%q, keeping default %s", key, raw, fallback)
		return fallback
	}
	return value
}
