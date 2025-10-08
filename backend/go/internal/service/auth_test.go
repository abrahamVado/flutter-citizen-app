package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

// 1.- fakeUserRepository simula la persistencia de usuarios para las pruebas.
type fakeUserRepository struct {
	mu    sync.RWMutex
	users map[string]string
}

func newFakeUserRepository() *fakeUserRepository {
	return &fakeUserRepository{users: make(map[string]string)}
}

func (f *fakeUserRepository) Create(_ context.Context, email, passwordHash string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, exists := f.users[email]; exists {
		return ErrEmailConflict
	}
	f.users[email] = passwordHash
	return nil
}

func (f *fakeUserRepository) PasswordHash(_ context.Context, email string) (string, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	hash, ok := f.users[email]
	if !ok {
		return "", ErrInvalidCredentials
	}
	return hash, nil
}

func (f *fakeUserRepository) Exists(_ context.Context, email string) (bool, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	_, ok := f.users[email]
	return ok, nil
}

func TestAuthenticateFlowRequiresRegistration(t *testing.T) {
	// 2.- Preparamos el servicio y confirmamos que la autenticación falla sin registro previo.
	repo := newFakeUserRepository()
	svc := NewAuthService(repo, 1, 2*time.Minute)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if _, err := svc.Authenticate(ctx, "user@example.com", "s3cr3t"); !errors.Is(err, ErrInvalidCredentials) {
		t.Fatalf("expected invalid credentials before registration, got %v", err)
	}

	// 3.- Registramos al usuario y validamos la generación del token inicial.
	initial, err := svc.Register(ctx, "user@example.com", "s3cr3t")
	if err != nil {
		t.Fatalf("Register returned error: %v", err)
	}
	if initial.Token == "" {
		t.Fatalf("expected non empty token on register")
	}

	// 4.- Ejecutamos la autenticación y confirmamos que el TTL es razonable.
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
	repo := newFakeUserRepository()
	svc := NewAuthService(repo, 1, time.Minute)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// 2.- Verificamos que el servicio devuelva el error del contexto.
	if _, err := svc.Authenticate(ctx, "mail", "pwd"); err == nil {
		t.Fatalf("expected context cancellation error")
	}
}
