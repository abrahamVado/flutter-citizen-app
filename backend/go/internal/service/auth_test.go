package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"
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
	svc := NewAuthService(repo, 1, 2*time.Minute, []byte("test-secret"))
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
	svc := NewAuthService(repo, 1, time.Minute, []byte("test-secret"))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// 2.- Verificamos que el servicio devuelva el error del contexto.
	if _, err := svc.Authenticate(ctx, "mail", "pwd"); err == nil {
		t.Fatalf("expected context cancellation error")
	}
}

func TestRegisterStoresBCryptHashAndIssuesJWT(t *testing.T) {
	// 1.- Configuramos el servicio de autenticación con un repositorio falso.
	repo := newFakeUserRepository()
	svc := NewAuthService(repo, 1, time.Minute, []byte("jwt-secret"))
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// 2.- Ejecutamos el registro y verificamos que no regrese errores.
	resp, err := svc.Register(ctx, "hash@example.com", "ClaveFuerte1")
	if err != nil {
		t.Fatalf("unexpected register error: %v", err)
	}
	if resp.Token == "" {
		t.Fatalf("expected jwt token in response")
	}

	// 3.- Confirmamos que el hash guardado no coincide con el texto plano.
	repo.mu.RLock()
	stored := repo.users["hash@example.com"]
	repo.mu.RUnlock()
	if stored == "ClaveFuerte1" {
		t.Fatalf("password stored as plain text")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(stored), []byte("ClaveFuerte1")); err != nil {
		t.Fatalf("bcrypt comparison failed: %v", err)
	}

	// 4.- Validamos el JWT y recuperamos el sujeto.
	subject, err := svc.ValidateToken(resp.Token)
	if err != nil {
		t.Fatalf("token validation failed: %v", err)
	}
	if subject != "hash@example.com" {
		t.Fatalf("expected subject hash@example.com, got %s", subject)
	}
}
