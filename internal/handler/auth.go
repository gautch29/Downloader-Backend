package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gautch29/downloader-backend/internal/database"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	var storedHash string
	var userID int
	err := database.Pool.QueryRow(r.Context(), "SELECT id, password_hash FROM users WHERE username=$1", req.Username).Scan(&userID, &storedHash)
	if err == pgx.ErrNoRows {
		RespondError(w, http.StatusUnauthorized, "Invalid credentials")
		return
	} else if err != nil {
		RespondError(w, http.StatusInternalServerError, "Database error")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(req.Password)); err != nil {
		RespondError(w, http.StatusUnauthorized, "Invalid credentials")
		return
	}

	// Generate Session Token
	token := uuid.New().String()
	expiresAt := time.Now().Add(30 * 24 * time.Hour) // 30 days

	// Store in DB
	_, err = database.Pool.Exec(r.Context(), "INSERT INTO sessions (user_id, token, expires_at) VALUES ($1, $2, $3)", userID, token, expiresAt)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to create session")
		return
	}

	// Set Cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "session_id",
		Value:    token,
		Expires:  expiresAt,
		Path:     "/",
		HttpOnly: true,
		// Secure:   true, // Uncomment if using HTTPS
		SameSite: http.SameSiteLaxMode,
	})

	RespondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"user": map[string]string{
			"username": req.Username,
		},
	})
}

func Logout(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("session_id")
	if err == nil {
		// Delete from DB (best effort)
		database.Pool.Exec(r.Context(), "DELETE FROM sessions WHERE token=$1", cookie.Value)
	}

	// Clear Cookie
	http.SetCookie(w, &http.Cookie{
		Name:     "session_id",
		Value:    "",
		Expires:  time.Unix(0, 0),
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
	})

	RespondJSON(w, http.StatusOK, map[string]bool{"success": true})
}
