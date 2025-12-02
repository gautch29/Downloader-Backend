# Downloader App

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Vapor](https://img.shields.io/badge/Vapor-4.0-purple.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

A modern, self-hosted download manager built with **Swift (Vapor)** and **Next.js**. This application allows you to search for movies, manage downloads from 1fichier, and integrate seamlessly with Plex.

## Features

-   **Swift Backend**: High-performance, type-safe backend using Vapor 4.
-   **Next.js Frontend**: Responsive and modern UI (React 19, TailwindCSS).
-   **Zone-Telechargement Integration**: Search and download movies directly.
-   **1fichier Support**: Automatically extracts and downloads files from 1fichier links.
-   **Plex Integration**: Automatically scans your Plex library upon download completion.
-   **User Authentication**: Secure login with session management.
-   **Systemd Support**: Run as a background service on Linux.

## Tech Stack

-   **Backend**: Swift 6, Vapor 4, Fluent (SQLite), SwiftSoup, JWT/BCrypt.
-   **Frontend**: Next.js 15, React 19, TailwindCSS, Shadcn/UI.
-   **Database**: SQLite (stored in `../downloader-data`).

## Quick Start

### Prerequisites

-   Swift 6.0+
-   Node.js 20+
-   npm

### 1. Backend Setup

```bash
cd backend
swift build
swift run Run migrate -y
swift run Run serve --hostname 0.0.0.0 --port 8080
```

### 2. Frontend Setup

```bash
# Install dependencies
npm install

# Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Configuration

The application stores its configuration in `config/settings.json`.
You can copy the example file to get started:

```bash
cp config/settings.example.json config/settings.json
```

## Documentation

-   [Technical Documentation](docs/DOCUMENTATION.md)
-   [API Documentation](docs/API_DOCUMENTATION.md)
-   [Database Guide](docs/DATABASE.md)
-   [Production Setup](docs/PRODUCTION_SETUP.md)
-   [Proxmox Deployment](docs/PROXMOX_SETUP.md)

## Deployment

### Systemd Service

To run the backend as a systemd service on Linux, see the [Systemd Setup Guide](docs/SYSTEMD_SETUP.md) (coming soon) or check the `downloader-backend.service` file.

## License

MIT
