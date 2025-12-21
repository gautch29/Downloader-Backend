package model

import (
	"time"
)

type User struct {
	ID           int       `json:"id" db:"id"`
	Username     string    `json:"username" db:"username"`
	PasswordHash string    `json:"-" db:"password_hash"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type DownloadStatus string

const (
	StatusPending     DownloadStatus = "pending"
	StatusDownloading DownloadStatus = "downloading"
	StatusCompleted   DownloadStatus = "completed"
	StatusError       DownloadStatus = "error"
)

type Download struct {
	ID             int            `json:"id" db:"id"`
	URL            string         `json:"url" db:"url"`
	Filename       *string        `json:"filename,omitempty" db:"filename"`
	CustomFilename *string        `json:"custom_filename,omitempty" db:"custom_filename"`
	TargetPath     *string        `json:"target_path,omitempty" db:"target_path"`
	Status         DownloadStatus `json:"status" db:"status"`
	Progress       int            `json:"progress" db:"progress"`
	Size           *int64         `json:"size,omitempty" db:"size"`
	Speed          *int           `json:"speed,omitempty" db:"speed"`
	ETA            *int           `json:"eta,omitempty" db:"eta"`
	Error          *string        `json:"error,omitempty" db:"error"`
	CreatedAt      time.Time      `json:"created_at" db:"created_at"`
	UpdatedAt      *time.Time     `json:"updated_at,omitempty" db:"updated_at"`
}

type Session struct {
	ID        int       `json:"id" db:"id"`
	UserID    int       `json:"user_id" db:"user_id"`
	Token     string    `json:"token" db:"token"`
	ExpiresAt time.Time `json:"expires_at" db:"expires_at"`
}

type Setting struct {
	Key   string `json:"key" db:"key"`
	Value string `json:"value" db:"value"`
}

type Path struct {
	ID   int    `json:"id" db:"id"`
	Name string `json:"name" db:"name"`
	Path string `json:"path" db:"path"`
}
