# dl.flgr.fr - Technical Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Database Schema](#database-schema)
4. [Security & Authentication](#security--authentication)
5. [Core Components](#core-components)
6. [API Integration](#api-integration)
7. [File Management](#file-management)
8. [Deployment](#deployment)
9. [Configuration](#configuration)

---

## Project Overview

**dl.flgr.fr** is a premium 1fichier download manager featuring:
- Secure user authentication with session management
- Queue-based download system with real-time progress tracking
- Plex Media Server integration for automatic library scanning
- Bilingual interface (English/French)
- Modern UI with system theme support
- Path shortcuts for organized file management

**Tech Stack:**
- **Backend**: Swift 6, Vapor 4
- **Frontend**: Next.js 15 (React 19)
- **Database**: SQLite (Fluent ORM)
- **Authentication**: JWT / BCrypt
- **Styling**: Tailwind CSS with Shadcn/UI

---

## Architecture

### Application Structure

#### Backend (Swift/Vapor)
```
/Sources
  /App
    /Controllers       # Request handlers (Auth, Downloads, etc.)
    /Models           # Fluent models (User, Download, etc.)
    /Services         # Business logic (DownloadManager, Scraper)
    /Migrations       # Database schema migrations
    configure.swift   # App configuration & middleware
    routes.swift      # Route definitions
```

#### Frontend (Next.js)
```
/app                    # Next.js App Router pages
/components            # Reusable UI components
/lib                   # Core business logic
```

### Process Architecture

The application consists of:

1. **Backend Service** (`Run`):
   - Vapor web server (port 8080)
   - Handles API requests
   - Manages background download worker (in-process)
   - Serves as the source of truth for download state

2. **Frontend Service** (Next.js):
   - Serves the UI (port 3000)
   - Consumes Backend API

---

## Database Schema

**Database**: SQLite (`downloader.db`)
**ORM**: Fluent

### Tables

#### `downloads`
Stores download queue and status.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `url` | STRING | 1fichier URL |
| `filename` | STRING | Detected filename |
| `custom_filename` | STRING | User-specified filename |
| `target_path` | STRING | Download destination path |
| `status` | STRING | `pending`, `downloading`, `completed`, `error` |
| `progress` | DOUBLE | Download progress (0-100) |
| `size` | INT64 | File size in bytes |
| `speed` | DOUBLE | Download speed in bytes/sec |
| `eta` | DOUBLE | Estimated seconds remaining |
| `error` | STRING | Error message |

#### `users`
Stores user accounts.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `username` | STRING | Unique username |
| `password_hash` | STRING | BCrypt hash |

#### `sessions`
Stores active user sessions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key to `users.id` |
| `token` | STRING | Session token |
| `expires_at` | DATE | Expiration time |

#### `settings`
Stores application-wide settings.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `plex_url` | STRING | Plex Media Server URL |
| `plex_token` | STRING | Plex authentication token |
| `api_key` | STRING | 1fichier API Key |

---

## Security & Authentication

### Password Security
- **Algorithm**: BCrypt
- **Storage**: Only hashes are stored.

### Session Management
- **Token**: JWT / Secure Random String
- **Storage**: HTTP-only cookies
- **Validation**: Middleware checks session validity on protected routes.

---

## Core Components

### 1. Download Manager (`DownloadManager.swift`)
- **Purpose**: Manages the download queue and background processing.
- **Behavior**:
  - Polls for pending downloads.
  - Executes downloads using `curl` or native Swift streams.
  - Updates progress in the database.
  - Triggers Plex scan on completion.

### 2. Scraper Service (`ScraperService.swift`)
- **Purpose**: Integrates with Zone-Telechargement (or similar) to search for movies.
- **Features**:
  - Parses search results.
  - Extracts 1fichier links.

### 3. Plex Integration
- **Trigger**: HTTP GET request to Plex Media Server.
- **Endpoint**: `/library/sections/all/refresh`

---

## API Integration

### 1fichier API
- **Endpoint**: `https://api.1fichier.com/v1/download/get_token.cgi`
- **Auth**: Bearer Token (stored in Settings)

---

## File Management

### Download Directory
- Default: `../downloader-data/downloads` (relative to executable) or configured via `DOWNLOAD_DIR`.
- **Structure**: Flat or organized by user selection.

### Path Shortcuts
- Users can define shortcuts for common paths (e.g., `/mnt/movies`).
- Stored in the database (`paths` table).

---

## Deployment

### Systemd (Linux)
The backend can run as a systemd service. See `downloader-backend.service`.

### Environment Variables
- `DATA_DIR`: Path to store database and downloads (default: `../downloader-data`).
- `PORT`: Server port (default: 8080).

---

## Configuration

### User Management
Use the CLI commands to manage users:
```bash
swift run Run create-user <username> <password>
```

### API Key
Set the 1fichier API key:
```bash
swift run Run set-api-key <key>
```

---

## Troubleshooting

### Common Issues

**1. Downloads stuck in "pending"**
- Check backend logs (`journalctl -u downloader-backend`).
- Verify 1fichier API key.

**2. Permission errors**
- Ensure the backend service has write access to the download directory.

**3. Plex scan not triggering**
- Verify Plex URL and Token in Settings.
- Check network connectivity between backend and Plex.
