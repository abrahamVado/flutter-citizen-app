package service

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"time"
)

// 1.- AuthService administra solicitudes concurrentes de autenticación.
type AuthService struct {
	jobs     chan authJob
	workers  int
	tokenTTL time.Duration
}

type authJob struct {
	email    string
	password string
	ctx      context.Context
	result   chan<- AuthResponse
}

// 2.- AuthResponse modela la respuesta esperada por el cliente Flutter.
type AuthResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
}

// 3.- NewAuthService configura el pool de trabajadores.
func NewAuthService(workers int, tokenTTL time.Duration) *AuthService {
	s := &AuthService{
		jobs:     make(chan authJob),
		workers:  workers,
		tokenTTL: tokenTTL,
	}
	for i := 0; i < workers; i++ {
		go s.worker()
	}
	return s
}

// 4.- Authenticate coloca el trabajo en cola y espera el resultado.
func (s *AuthService) Authenticate(ctx context.Context, email, password string) (AuthResponse, error) {
	resultCh := make(chan AuthResponse, 1)
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
		return res, nil
	}
}

// 5.- worker procesa cada autenticación en segundo plano.
func (s *AuthService) worker() {
	for job := range s.jobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		hasher := sha1.New()
		hasher.Write([]byte(fmt.Sprintf("%s:%s", job.email, job.password)))
		token := hex.EncodeToString(hasher.Sum(nil))
		job.result <- AuthResponse{
			Token:     token,
			ExpiresAt: time.Now().Add(s.tokenTTL),
		}
	}
}
