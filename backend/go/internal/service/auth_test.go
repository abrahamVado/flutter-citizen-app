package service

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"testing"
	"time"
)

func TestAuthenticateGeneratesDeterministicToken(t *testing.T) {
	// 1.- Preparamos el servicio con un TTL breve para validar el cálculo.
	svc := NewAuthService(1, 2*time.Minute)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	// 2.- Ejecutamos la autenticación de un usuario controlado.
	resp, err := svc.Authenticate(ctx, "user@example.com", "s3cr3t")
	if err != nil {
		t.Fatalf("Authenticate returned error: %v", err)
	}

	// 3.- Calculamos el token esperado usando el mismo algoritmo determinista.
	hasher := sha1.New()
	hasher.Write([]byte("user@example.com:s3cr3t"))
	expected := hex.EncodeToString(hasher.Sum(nil))
	if resp.Token != expected {
		t.Fatalf("unexpected token: got %q want %q", resp.Token, expected)
	}

	// 4.- Confirmamos que la expiración esté dentro del rango previsto.
	remaining := time.Until(resp.ExpiresAt)
	if remaining < time.Minute || remaining > 2*time.Minute+time.Second {
		t.Fatalf("unexpected ttl window: %s", remaining)
	}
}

func TestAuthenticateRespectsContextCancellation(t *testing.T) {
	// 1.- Creamos un contexto cancelado que debe propagarse al servicio.
	svc := NewAuthService(1, time.Minute)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// 2.- Verificamos que el servicio devuelva el error del contexto.
	if _, err := svc.Authenticate(ctx, "mail", "pwd"); err == nil {
		t.Fatalf("expected context cancellation error")
	}
}
