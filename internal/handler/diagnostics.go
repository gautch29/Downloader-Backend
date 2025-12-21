package handler

import (
	"fmt"
	"net/http"
	"os"

	"github.com/gautch29/downloader-backend/internal/database"
	"github.com/gautch29/downloader-backend/internal/integration/onefichier"
	"github.com/gautch29/downloader-backend/internal/integration/plex"
	"github.com/gautch29/downloader-backend/internal/integration/zonetelechargement"
	"github.com/gautch29/downloader-backend/internal/util"
)

type ValidationResult struct {
	Service string `json:"service"`
	Status  string `json:"status"` // "ok" or "error"
	Message string `json:"message,omitempty"`
}

type DiagnosticsResponse struct {
	Checks []ValidationResult `json:"checks"`
	Disk   map[string]string  `json:"disk_space"`
}

func RunDiagnostics(w http.ResponseWriter, r *http.Request) {
	var checks []ValidationResult

	// 1. Database Check
	dbCheck := ValidationResult{Service: "Database", Status: "ok"}
	if err := database.Pool.Ping(r.Context()); err != nil {
		dbCheck.Status = "error"
		dbCheck.Message = err.Error()
	}
	checks = append(checks, dbCheck)

	// 2. 1fichier Check
	ofKey := os.Getenv("ONEFICHIER_API_KEY")
	ofCheck := ValidationResult{Service: "1fichier", Status: "ok"}
	if err := onefichier.NewClient(ofKey).CheckAPI(); err != nil {
		ofCheck.Status = "error"
		ofCheck.Message = err.Error()
	}
	checks = append(checks, ofCheck)

	// 3. Plex Check
	plexUrl := ""   // TODO: Fetch from settings DB
	plexToken := "" // TODO: Fetch from settings DB

	// Fetch settings for Plex
	var key, value string
	rows, _ := database.Pool.Query(r.Context(), "SELECT key, value FROM settings WHERE key IN ('plexUrl', 'plexToken')")
	defer rows.Close()
	for rows.Next() {
		rows.Scan(&key, &value)
		if key == "plexUrl" {
			plexUrl = value
		}
		if key == "plexToken" {
			plexToken = value
		}
	}

	plexCheck := ValidationResult{Service: "Plex", Status: "ok"}
	if plexUrl != "" {
		if err := plex.NewClient(plexUrl, plexToken).CheckConnection(); err != nil {
			plexCheck.Status = "error"
			plexCheck.Message = err.Error()
		}
	} else {
		plexCheck.Status = "warning"
		plexCheck.Message = "Not configured"
	}
	checks = append(checks, plexCheck)

	// 4. Zone-Telechargement Check
	ztCheck := ValidationResult{Service: "Zone-Telechargement", Status: "ok"}
	if err := zonetelechargement.CheckConnectivity(); err != nil {
		ztCheck.Status = "error"
		ztCheck.Message = err.Error()
	}
	checks = append(checks, ztCheck)

	// 5. Disk Space (Check paths from DB)
	diskSpace := make(map[string]string)
	pathRows, _ := database.Pool.Query(r.Context(), "SELECT name, path FROM paths")
	defer pathRows.Close()

	// Always check current working dir
	wd, _ := os.Getwd()
	if free, err := util.GetFreeSpace(wd); err == nil {
		diskSpace["App (Internal)"] = fmt.Sprintf("%.2f GB", float64(free)/1024/1024/1024)
	}

	for pathRows.Next() {
		var name, p string
		pathRows.Scan(&name, &p)
		if free, err := util.GetFreeSpace(p); err == nil {
			diskSpace[name] = fmt.Sprintf("%.2f GB", float64(free)/1024/1024/1024)
		} else {
			diskSpace[name] = "Error reading path"
		}
	}

	RespondJSON(w, http.StatusOK, DiagnosticsResponse{
		Checks: checks,
		Disk:   diskSpace,
	})
}
