package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"
	"os/signal"
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

	// 2.- Inicializamos los servicios concurrentes requeridos por el API.
	userRepo := repository.NewPostgresUserRepository(db)
	reportRepo := repository.NewPostgresReportRepository(db)
	authService := service.NewAuthService(userRepo, 4, 8*time.Hour)
	catalogService := service.NewCatalogService(2)
	reportService := service.NewReportService(reportRepo, 4, 4)

	// 3.- Construimos el enrutador HTTP basado en los servicios previos.
	srv := httpserver.New(authService, catalogService, reportService)
	handler := srv.Router()

	// 4.- Configuramos el servidor tomando el puerto del entorno si existe.
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

	// 5.- Manejamos la terminación elegante ante señales del sistema.
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
