# Downloader App (Go Backend)

![Go](https://img.shields.io/badge/Go-1.24-blue.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

A modern, self-hosted download manager rewritten in **Go**. This application allows you to search for movies, manage downloads from 1fichier, and integrate seamlessly with Plex.

## Features

-   **Go Backend**: High-performance, lightweight backend using standard library + minimal dependencies.
-   **Remote PostgreSQL**: Stateless architecture using an external database.
-   **1fichier Support**: Automatically extracts and downloads files from 1fichier links.
-   **Plex Integration**: Automatically scans your Plex library upon download completion.
-   **User Authentication**: Secure login with session management.

## Tech Stack

-   **Backend**: Go (Golang) 1.22+, `chi` router, `pgx` driver.
-   **Database**: PostgreSQL.

## Quick Start

### Prerequisites

-   Go 1.22+
-   PostgreSQL Database

### Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/gautch29/downloader-backend.git
    cd downloader-backend
    ```

2.  **Configuration**:
    Create a `.env` file based on `.env.example`:
    ```bash
    cp .env.example .env
    ```
    Edit `.env` and populate your variables:
    -   `DATABASE_URL`: Connection string (e.g., `postgres://user:pass@host:5432/dbname`)
    -   `PORT`: Server port (default: 8080)
    -   `JWT_SECRET`: Random string for signing sessions
    -   `ONEFICHIER_API_KEY`: Your 1fichier API key

3.  **Run**:
    ```bash
    go mod tidy
    go run cmd/server/main.go
    ```
    Alternatively, build the binary:
    ```bash
    go build -o server ./cmd/server/main.go
    ./server
    ```

## API Documentation

-   **Health Check**: `GET /api/health`
-   **Login**: `POST /api/auth/login`
-   **Downloads**: `GET /api/downloads`, `POST /api/downloads`

See [docs/API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md) for full details.

## License

MIT
