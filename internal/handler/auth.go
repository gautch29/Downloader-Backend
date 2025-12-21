package handler

import (
	"encoding/json"
	"net/http"

	"github.com/gautch29/downloader-backend/internal/database"
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

	// TODO: Generate and store session token
	// For now, just return success
	RespondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"user": map[string]string{
			"username": req.Username,
		},
	})
}

func Logout(w http.ResponseWriter, r *http.Request) {
	// TODO: Invalidate session
	RespondJSON(w, http.StatusOK, map[string]bool{"success": true})
}
