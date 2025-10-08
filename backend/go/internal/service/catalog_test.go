package service

import (
	"context"
	"testing"
	"time"
)

func TestCatalogFetchReturnsIsolatedCopy(t *testing.T) {
	// 1.- Instanciamos el servicio con un único trabajador para simplificar la prueba.
	svc := NewCatalogService(1)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	// 2.- Obtenemos el catálogo y modificamos la copia devuelta.
	catalog, err := svc.Fetch(ctx)
	if err != nil {
		t.Fatalf("Fetch returned error: %v", err)
	}
	if len(catalog) == 0 {
		t.Fatalf("expected catalog entries")
	}
	catalog[0].Name = "Alterado"

	// 3.- Recuperamos nuevamente para garantizar que la fuente se mantiene intacta.
	second, err := svc.Fetch(ctx)
	if err != nil {
		t.Fatalf("Fetch returned error: %v", err)
	}
	if second[0].Name == "Alterado" {
		t.Fatalf("catalog should be isolated copies between calls")
	}
}
