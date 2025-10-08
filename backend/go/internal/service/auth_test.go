package service

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestAuthenticateFlowRequiresRegistration(t *testing.T) {
	// 1.- Preparamos el servicio y confirmamos que la autenticación falla sin registro previo.
	svc := NewAuthService(1, 2*time.Minute)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if _, err := svc.Authenticate(ctx, "user@example.com", "s3cr3t"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("expected invalid credentials before registration, got %v", err)
	}

	// 2.- Registramos al usuario y validamos la generación del token inicial.
	initial, err := svc.Register(ctx, "user@example.com", "s3cr3t")
	if err != nil {
		t.Fatalf("Register returned error: %v", err)
	}
	if initial.Token == "" {
		t.Fatalf("expected non empty token on register")
	}

	// 3.- Ejecutamos la autenticación y confirmamos que el TTL es razonable.
	resp, err := svc.Authenticate(ctx, "user@example.com", "s3cr3t")
	if err != nil {
		t.Fatalf("Authenticate returned error: %v", err)
	}
	if resp.Token == "" {
		t.Fatalf("expected token value on authenticate")
	}
	if time.Until(resp.ExpiresAt) <= 0 {
		t.Fatalf("expected future expiration, got %v", resp.ExpiresAt)
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
