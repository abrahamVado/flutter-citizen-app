package service

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

// 1.- AuthService administra solicitudes concurrentes y persistencia efímera.
type AuthService struct {
	jobs     chan authJob
	workers  int
	tokenTTL time.Duration
	users    map[string]string
	mu       sync.RWMutex
}

type authJob struct {
	email    string
	password string
	ctx      context.Context
	result   chan<- authResult
}

type authResult struct {
	response AuthResponse
	err      error
}

// 2.- AuthResponse modela la respuesta esperada por el cliente Flutter.
type AuthResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
}

// 3.- Declaramos errores reutilizables para mapear códigos HTTP.
var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrEmailConflict      = errors.New("email already registered")
	ErrUnsupportedLogin   = errors.New("unsupported provider")
)

// 4.- NewAuthService configura el pool de trabajadores y los registros en memoria.
func NewAuthService(workers int, tokenTTL time.Duration) *AuthService {
	s := &AuthService{
		jobs:     make(chan authJob),
		workers:  workers,
		tokenTTL: tokenTTL,
		users:    make(map[string]string),
	}
	for i := 0; i < workers; i++ {
		go s.worker()
	}
	return s
}

// 5.- Authenticate coloca el trabajo en cola y espera el resultado.
func (s *AuthService) Authenticate(ctx context.Context, email, password string) (AuthResponse, error) {
	resultCh := make(chan authResult, 1)
	job := authJob{email: email, password: password, ctx: ctx, result: resultCh}
	select {
	case <-ctx.Done():
		return AuthResponse{}, ctx.Err()
	case s.jobs <- job:
	}
	select {
	case <-ctx.Done():
		return AuthResponse{}, ctx.Err()
	case res := <-resultCh:
		if res.err != nil {
			return AuthResponse{}, res.err
		}
		return res.response, nil
	}
}

// 6.- Register almacena un nuevo usuario y devuelve un token recién emitido.
func (s *AuthService) Register(ctx context.Context, email, password string) (AuthResponse, error) {
	select {
	case <-ctx.Done():
		return AuthResponse{}, ctx.Err()
	default:
	}
	normalized := strings.TrimSpace(strings.ToLower(email))
	if normalized == "" || strings.TrimSpace(password) == "" {
		return AuthResponse{}, ErrInvalidCredentials
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.users[normalized]; exists {
		return AuthResponse{}, ErrEmailConflict
	}
	s.users[normalized] = s.hashPassword(password)
	return s.newToken(normalized), nil
}

// 7.- Recover valida la existencia de la cuenta para simular el envío de correo.
func (s *AuthService) Recover(ctx context.Context, email string) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}
	normalized := strings.TrimSpace(strings.ToLower(email))
	if normalized == "" {
		return ErrInvalidCredentials
	}
	s.mu.RLock()
	_, exists := s.users[normalized]
	s.mu.RUnlock()
	if !exists {
		return ErrInvalidCredentials
	}
	return nil
}

// 8.- SocialAuthenticate genera un token virtual para proveedores federados.
func (s *AuthService) SocialAuthenticate(ctx context.Context, provider string) (AuthResponse, error) {
	select {
	case <-ctx.Done():
		return AuthResponse{}, ctx.Err()
	default:
	}
	switch provider {
	case "google", "apple", "facebook":
		return s.newToken(provider), nil
	default:
		return AuthResponse{}, ErrUnsupportedLogin
	}
}

// 9.- worker procesa cada autenticación en segundo plano.
func (s *AuthService) worker() {
	for job := range s.jobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		normalized := strings.TrimSpace(strings.ToLower(job.email))
		s.mu.RLock()
		stored, exists := s.users[normalized]
		s.mu.RUnlock()
		if !exists || stored != s.hashPassword(job.password) {
			job.result <- authResult{err: ErrInvalidCredentials}
			continue
		}
		job.result <- authResult{response: s.newToken(normalized)}
	}
}

// 10.- newToken centraliza la construcción del token y expiración.
func (s *AuthService) newToken(seed string) AuthResponse {
	hasher := sha1.New()
	hasher.Write([]byte(fmt.Sprintf("%s:%d", seed, time.Now().UnixNano())))
	return AuthResponse{
		Token:     hex.EncodeToString(hasher.Sum(nil)),
		ExpiresAt: time.Now().Add(s.tokenTTL),
	}
}

// 11.- hashPassword asegura que las contraseñas se guarden homogeneizadas.
func (s *AuthService) hashPassword(password string) string {
	hasher := sha1.New()
	hasher.Write([]byte(password))
	return hex.EncodeToString(hasher.Sum(nil))
}
