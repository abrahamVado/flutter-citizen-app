package repository

import (
	"context"
	"database/sql"

	"citizenapp/backend/internal/service"
)

// 1.- PostgresUserRepository implementa service.UserRepository usando SQL.
type PostgresUserRepository struct {
	db *sql.DB
}

// 2.- NewPostgresUserRepository valida la conexión inyectada.
func NewPostgresUserRepository(db *sql.DB) *PostgresUserRepository {
	if db == nil {
		panic("postgres db is required")
	}
	return &PostgresUserRepository{db: db}
}

// 3.- Create inserta el usuario o devuelve ErrEmailConflict si ya existe.
func (r *PostgresUserRepository) Create(ctx context.Context, email, passwordHash string) error {
	const query = `
                INSERT INTO users (email, password_hash, created_at)
                VALUES ($1, $2, NOW())
                ON CONFLICT (email) DO NOTHING
        `
	result, err := r.db.ExecContext(ctx, query, email, passwordHash)
	if err != nil {
		return err
	}
	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return service.ErrEmailConflict
	}
	return nil
}

// 4.- PasswordHash devuelve el hash guardado o ErrInvalidCredentials.
func (r *PostgresUserRepository) PasswordHash(ctx context.Context, email string) (string, error) {
	const query = `
                SELECT password_hash
                FROM users
                WHERE email = $1
        `
	var hash string
	if err := r.db.QueryRowContext(ctx, query, email).Scan(&hash); err != nil {
		if err == sql.ErrNoRows {
			return "", service.ErrInvalidCredentials
		}
		return "", err
	}
	return hash, nil
}

// 5.- Exists confirma la presencia del usuario en la tabla.
func (r *PostgresUserRepository) Exists(ctx context.Context, email string) (bool, error) {
	const query = `
                SELECT EXISTS (SELECT 1 FROM users WHERE email = $1)
        `
	var exists bool
	if err := r.db.QueryRowContext(ctx, query, email).Scan(&exists); err != nil {
		return false, err
	}
	return exists, nil
}
