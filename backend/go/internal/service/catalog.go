package service

import (
	"context"
)

// 1.- CatalogService maneja la recuperación concurrente del catálogo de incidentes.
type CatalogService struct {
	jobs    chan catalogJob
	workers int
}

type catalogJob struct {
	ctx    context.Context
	result chan<- []IncidentType
}

// 2.- IncidentType modela cada tipo de incidente disponible.
type IncidentType struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	RequiresEvidence bool   `json:"requiresEvidence"`
}

var defaultCatalog = []IncidentType{
	{ID: "pothole", Name: "Bache", RequiresEvidence: true},
	{ID: "lighting", Name: "Alumbrado público", RequiresEvidence: false},
	{ID: "trash", Name: "Basura acumulada", RequiresEvidence: true},
}

// 3.- NewCatalogService prepara a los trabajadores en memoria.
func NewCatalogService(workers int) *CatalogService {
	s := &CatalogService{
		jobs:    make(chan catalogJob),
		workers: workers,
	}
	for i := 0; i < workers; i++ {
		go s.worker()
	}
	return s
}

// 4.- Fetch envía el trabajo concurrente y espera el catálogo.
func (s *CatalogService) Fetch(ctx context.Context) ([]IncidentType, error) {
	resultCh := make(chan []IncidentType, 1)
	job := catalogJob{ctx: ctx, result: resultCh}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case s.jobs <- job:
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case res := <-resultCh:
		return res, nil
	}
}

// 5.- worker clona el catálogo simulando un acceso remoto.
func (s *CatalogService) worker() {
	for job := range s.jobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		cloned := make([]IncidentType, len(defaultCatalog))
		copy(cloned, defaultCatalog)
		job.result <- cloned
	}
}
