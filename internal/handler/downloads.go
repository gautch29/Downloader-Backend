package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gautch29/downloader-backend/internal/database"
	"github.com/gautch29/downloader-backend/internal/model"
	"github.com/go-chi/chi/v5"
)

func ListDownloads(w http.ResponseWriter, r *http.Request) {
	rows, err := database.Pool.Query(r.Context(), "SELECT id, url, filename, status, progress, size, created_at FROM downloads ORDER BY created_at DESC")
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to fetch downloads")
		return
	}
	defer rows.Close()

	var downloads []model.Download
	for rows.Next() {
		var dl model.Download
		// Scan fields matching the query
		if err := rows.Scan(&dl.ID, &dl.URL, &dl.Filename, &dl.Status, &dl.Progress, &dl.Size, &dl.CreatedAt); err != nil {
			RespondError(w, http.StatusInternalServerError, "Failed to scan download")
			return
		}
		downloads = append(downloads, dl)
	}

	RespondJSON(w, http.StatusOK, downloads)
}

type AddDownloadRequest struct {
	URL            string `json:"url"`
	CustomFilename string `json:"customFilename"`
	TargetPath     string `json:"targetPath"`
}

func AddDownload(w http.ResponseWriter, r *http.Request) {
	var req AddDownloadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	_, err := database.Pool.Exec(r.Context(),
		"INSERT INTO downloads (url, custom_filename, target_path, status, created_at) VALUES ($1, $2, $3, $4, NOW())",
		req.URL, req.CustomFilename, req.TargetPath, model.StatusPending)

	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to insert download")
		return
	}

	RespondJSON(w, http.StatusCreated, map[string]string{"status": "queued"})
}

func DeleteDownload(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		RespondError(w, http.StatusBadRequest, "Invalid ID")
		return
	}

	_, err = database.Pool.Exec(r.Context(), "DELETE FROM downloads WHERE id=$1", id)
	if err != nil {
		RespondError(w, http.StatusInternalServerError, "Failed to delete download")
		return
	}

	RespondJSON(w, http.StatusOK, map[string]bool{"success": true})
}
