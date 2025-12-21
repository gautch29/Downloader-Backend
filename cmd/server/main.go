package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gautch29/downloader-backend/internal/database"
	"github.com/gautch29/downloader-backend/internal/handler"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file if it exists
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on environment variables")
	}

	// Connect to Database
	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Pool.Close()

	// Run Migrations
	if err := database.Migrate(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Setup Router
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	// r.Use(middleware.Cors) // TODO: Add CORS support with github.com/go-chi/cors

	// Public Routes
	r.Get("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Post("/api/auth/login", handler.Login)
	r.Post("/api/auth/logout", handler.Logout)

	// Protected Routes (TODO: Add Auth Middleware)
	r.Route("/api", func(r chi.Router) {
		// r.Use(handler.AuthMiddleware) // Commented out until implemented

		r.Get("/downloads", handler.ListDownloads)
		r.Post("/downloads", handler.AddDownload)
		r.Delete("/downloads/{id}", handler.DeleteDownload)

		r.Get("/settings", handler.GetSettings)
		r.Put("/settings", handler.UpdateSettings)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
