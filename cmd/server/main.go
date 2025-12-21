package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"

	"github.com/gautch29/downloader-backend/internal/database"
	"github.com/gautch29/downloader-backend/internal/handler"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
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

	// CLI Flags
	createUser := flag.Bool("create-user", false, "Create a new user")
	username := flag.String("username", "", "Username")
	password := flag.String("password", "", "Password")
	flag.Parse()

	// Run Migrations
	if err := database.Migrate(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Handle CLI Commands
	if *createUser {
		if *username == "" || *password == "" {
			log.Fatal("Username and password are required. Usage: -create-user -username <name> -password <pass>")
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(*password), bcrypt.DefaultCost)
		if err != nil {
			log.Fatalf("Failed to hash password: %v", err)
		}
		_, err = database.Pool.Exec(context.Background(), "INSERT INTO users (username, password_hash) VALUES ($1, $2)", *username, string(hash))
		if err != nil {
			log.Fatalf("Failed to create user: %v", err)
		}
		log.Printf("User '%s' created successfully!", *username)
		return
	}

	// Setup Router
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	// CORS Configuration
	// Since backend and frontend are on different hosts/ports, we need to allow cross-origin requests.
	// Adjust AllowedOrigins to matches your frontend's URL for better security.
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"}, // Allow all origins for now (adjust for production)
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}))

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
