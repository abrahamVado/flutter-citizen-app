package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	httpserver "citizenapp/backend/internal/http"
	"citizenapp/backend/internal/service"
)

func main() {
	// 1.- Inicializamos los servicios concurrentes requeridos por el API.
	authService := service.NewAuthService(4, 8*time.Hour)
	catalogService := service.NewCatalogService(2)
	reportService := service.NewReportService(4, 4)

	// 2.- Construimos el enrutador HTTP basado en los servicios previos.
	srv := httpserver.New(authService, catalogService, reportService)
	handler := srv.Router()

	// 3.- Configuramos el servidor tomando el puerto del entorno si existe.
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

	// 4.- Manejamos la terminación elegante ante señales del sistema.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("shutdown error: %v", err)
	}
}
