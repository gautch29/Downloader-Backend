package handler

import (
	"encoding/json"
	"net/http"

	"github.com/gautch29/downloader-backend/internal/database"
	"github.com/gautch29/downloader-backend/internal/model"
)

type SettingsResponse struct {
	Settings map[string]string `json:"settings"`
	Paths    []model.Path      `json:"paths"`
}

func GetSettings(w http.ResponseWriter, r *http.Request) {
	// Fetch Settings
	rows, err := database.Pool.Query(r.Context(), "SELECT key, value FROM settings")
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to fetch settings")
		return
	}
	defer rows.Close()

	settingsMap := make(map[string]string)
	for rows.Next() {
		var key, value string
		if err := rows.Scan(&key, &value); err != nil {
			continue
		}
		settingsMap[key] = value
	}

	// Fetch Paths
	pathRows, err := database.Pool.Query(r.Context(), "SELECT id, name, path FROM paths")
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to fetch paths")
		return
	}
	defer pathRows.Close()

	var paths []model.Path
	for pathRows.Next() {
		var p model.Path
		if err := pathRows.Scan(&p.ID, &p.Name, &p.Path); err != nil {
			continue
		}
		paths = append(paths, p)
	}

	RespondJSON(w, http.StatusOK, SettingsResponse{
		Settings: settingsMap,
		Paths:    paths,
	})
}

type UpdateSettingsRequest struct {
	PlexURL   string `json:"plexUrl"`
	PlexToken string `json:"plexToken"`
	Paths     []struct {
		Name string `json:"name"`
		Path string `json:"path"`
	} `json:"paths"`
}

func UpdateSettings(w http.ResponseWriter, r *http.Request) {
	var req UpdateSettingsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	ctx := r.Context()
	tx, err := database.Pool.Begin(ctx)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Database error")
		return
	}
	defer tx.Rollback(ctx)

	// Update Settings
	// Upsert query for settings
	upsertQuery := `INSERT INTO settings (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`
	if _, err := tx.Exec(ctx, upsertQuery, "plexUrl", req.PlexURL); err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to update plexUrl")
		return
	}
	if _, err := tx.Exec(ctx, upsertQuery, "plexToken", req.PlexToken); err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to update plexToken")
		return
	}

	// Update Paths: Full replace strategy (Delete all, insert new)
	if _, err := tx.Exec(ctx, "DELETE FROM paths"); err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to clear paths")
		return
	}

	for _, p := range req.Paths {
		if _, err := tx.Exec(ctx, "INSERT INTO paths (name, path) VALUES ($1, $2)", p.Name, p.Path); err != nil {
			RespondError(w, http.StatusInternalServerError, "Failed to insert path")
			return
		}
	}

	if err := tx.Commit(ctx); err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to commit changes")
		return
	}

	RespondJSON(w, http.StatusOK, map[string]bool{"success": true})
}
