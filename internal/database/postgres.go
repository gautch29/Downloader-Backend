package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func Connect() error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	config, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return fmt.Errorf("unable to parse database config: %w", err)
	}

	Pool, err = pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		return fmt.Errorf("unable to create connection pool: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := Pool.Ping(ctx); err != nil {
		return fmt.Errorf("unable to connect to database: %w", err)
	}

	log.Println("Connected to PostgreSQL successfully")
	return nil
}

func Migrate() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			username TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS downloads (
			id SERIAL PRIMARY KEY,
			url TEXT NOT NULL,
			filename TEXT,
			custom_filename TEXT,
			target_path TEXT,
			status TEXT NOT NULL DEFAULT 'pending',
			progress INTEGER NOT NULL DEFAULT 0,
			size BIGINT,
			speed INTEGER,
			eta INTEGER,
			error TEXT,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			updated_at TIMESTAMP WITH TIME ZONE
		);`,
		`CREATE TABLE IF NOT EXISTS sessions (
			id SERIAL PRIMARY KEY,
			user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			token TEXT NOT NULL UNIQUE,
			expires_at TIMESTAMP WITH TIME ZONE NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS settings (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);`,
		`CREATE TABLE IF NOT EXISTS paths (
			id SERIAL PRIMARY KEY,
			name TEXT NOT NULL,
			path TEXT NOT NULL
		);`,
	}

	ctx := context.Background()
	for _, query := range queries {
		_, err := Pool.Exec(ctx, query)
		if err != nil {
			return fmt.Errorf("migration failed for query %s: %w", query, err)
		}
	}

	log.Println("Database migrations applied successfully")
	return nil
}
