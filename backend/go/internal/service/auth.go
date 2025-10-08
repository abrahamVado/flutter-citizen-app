package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// 1.- AuthService administra solicitudes concurrentes con persistencia externa.
type AuthService struct {
	jobs      chan authJob
	workers   int
	tokenTTL  time.Duration
	repo      UserRepository
	jwtSecret []byte
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

// 2.- UserRepository define las operaciones requeridas para credenciales.
type UserRepository interface {
	Create(ctx context.Context, email, passwordHash string) error
	PasswordHash(ctx context.Context, email string) (string, error)
	Exists(ctx context.Context, email string) (bool, error)
}

// 3.- AuthResponse modela la respuesta esperada por el cliente Flutter.
type AuthResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
}

// 4.- Declaramos errores reutilizables para mapear códigos HTTP.
var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrEmailConflict      = errors.New("email already registered")
	ErrUnsupportedLogin   = errors.New("unsupported provider")
	ErrInvalidToken       = errors.New("invalid token")
)

// 5.- NewAuthService configura el pool de trabajadores y agrega la clave JWT.
func NewAuthService(repo UserRepository, workers int, tokenTTL time.Duration, jwtSecret []byte) *AuthService {
	if repo == nil {
		panic("user repository is required")
	}
	if len(jwtSecret) == 0 {
		panic("jwt secret is required")
	}
	s := &AuthService{
		jobs:      make(chan authJob),
		workers:   workers,
		tokenTTL:  tokenTTL,
		repo:      repo,
		jwtSecret: append([]byte(nil), jwtSecret...),
	}
	for i := 0; i < workers; i++ {
		go s.worker()
	}
	return s
}

// 6.- Authenticate coloca el trabajo en cola y espera el resultado.
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

// 7.- Register almacena un nuevo usuario y devuelve un token recién emitido.
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
	hashed, err := s.hashPassword(password)
	if err != nil {
		return AuthResponse{}, err
	}
	if err := s.repo.Create(ctx, normalized, hashed); err != nil {
		return AuthResponse{}, err
	}
	return s.newToken(normalized)
}

// 8.- Recover valida la existencia de la cuenta para simular el envío de correo.
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
	exists, err := s.repo.Exists(ctx, normalized)
	if err != nil {
		return err
	}
	if !exists {
		return ErrInvalidCredentials
	}
	return nil
}

// 9.- SocialAuthenticate genera un token virtual para proveedores federados.
func (s *AuthService) SocialAuthenticate(ctx context.Context, provider string) (AuthResponse, error) {
	select {
	case <-ctx.Done():
		return AuthResponse{}, ctx.Err()
	default:
	}
	switch provider {
	case "google", "apple", "facebook":
		return s.newToken(provider)
	default:
		return AuthResponse{}, ErrUnsupportedLogin
	}
}

// 10.- worker procesa cada autenticación en segundo plano.
func (s *AuthService) worker() {
	for job := range s.jobs {
		select {
		case <-job.ctx.Done():
			continue
		default:
		}
		normalized := strings.TrimSpace(strings.ToLower(job.email))
		stored, err := s.repo.PasswordHash(job.ctx, normalized)
		if err != nil {
			job.result <- authResult{err: err}
			continue
		}
		if err := s.verifyPassword(job.password, stored); err != nil {
			job.result <- authResult{err: ErrInvalidCredentials}
			continue
		}
		resp, err := s.newToken(normalized)
		if err != nil {
			job.result <- authResult{err: err}
			continue
		}
		job.result <- authResult{response: resp}
	}
}

// 11.- newToken centraliza la construcción del token y expiración.
func (s *AuthService) newToken(seed string) (AuthResponse, error) {
	now := time.Now()
	claims := jwt.RegisteredClaims{
		Subject:   seed,
		ExpiresAt: jwt.NewNumericDate(now.Add(s.tokenTTL)),
		IssuedAt:  jwt.NewNumericDate(now),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(s.jwtSecret)
	if err != nil {
		return AuthResponse{}, fmt.Errorf("sign token: %w", err)
	}
	return AuthResponse{
		Token:     signed,
		ExpiresAt: claims.ExpiresAt.Time,
	}, nil
}

// 12.- hashPassword asegura que las contraseñas se guarden homogeneizadas.
func (s *AuthService) hashPassword(password string) (string, error) {
	hashed, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("hash password: %w", err)
	}
	return string(hashed), nil
}

// 13.- verifyPassword compara la contraseña plana contra el hash almacenado.
func (s *AuthService) verifyPassword(password, hashed string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashed), []byte(password))
}

// 14.- ValidateToken analiza y verifica firmas HMAC para las rutas protegidas.
func (s *AuthService) ValidateToken(token string) (string, error) {
	parsed, err := jwt.ParseWithClaims(token, &jwt.RegisteredClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %s", t.Method.Alg())
		}
		return s.jwtSecret, nil
	}, jwt.WithLeeway(5*time.Second))
	if err != nil {
		return "", ErrInvalidToken
	}
	claims, ok := parsed.Claims.(*jwt.RegisteredClaims)
	if !ok || !parsed.Valid {
		return "", ErrInvalidToken
	}
	if claims.ExpiresAt == nil || time.Until(claims.ExpiresAt.Time) < 0 {
		return "", ErrInvalidToken
	}
	return claims.Subject, nil
}
