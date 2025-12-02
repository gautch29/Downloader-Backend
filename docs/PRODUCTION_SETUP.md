# Production Setup Guide

This guide covers how to set up, configure, and run the Downloader application in a production environment.

## 1. Prerequisites

- **Node.js**: v18 or higher
- **npm**: v9 or higher
- **PM2** (Optional but recommended): For managing background processes

## 2. Installation

1.  **Clone or copy the project files** to your server.
2.  **Install dependencies**:
    ```bash
    npm install
    ```

## 3. Configuration

Create a `.env` file in the root directory. You can copy `.env.example` if it exists, or create one from scratch:

```bash
# .env

# Database Configuration
# Use an absolute path to ensure it works for both the app and worker
DATABASE_URL="file:/home/downloader-data/downloader.db"

# Download Directory
# Where files will be downloaded to. MUST be an absolute path.
DOWNLOAD_DIR="/home/downloads"

# Security
# Generate a random string for session security
SESSION_SECRET="your-super-secret-random-string"

# Optional: Plex Integration
PLEX_URL="http://your-plex-server:32400"
PLEX_TOKEN="your-plex-token"
```

> [!IMPORTANT]
> Ensure the `DOWNLOAD_DIR` exists and is writable by the user running the application.

## 4. Database Setup

Initialize the database. This will create the database file and all necessary tables.

```bash
npm run init-db
```

> [!NOTE]
> By default, this creates the database at `/home/downloader-data/downloader.db` (or whatever path is configured in your `lib/db.ts` or `.env`).

## 5. User Management

You need to create at least one user to log in.

```bash
# Create a new user
npm run add-user

# Follow the prompts to enter username and password
```

Other user management commands:
```bash
# List all users
npm run list-users

# Delete a user
npm run delete-user
```

## 6. Running the Application

You need to run **two** processes: the web application and the background worker.

### Option A: Using PM2 (Recommended)

If you have PM2 installed (`npm install -g pm2`), this is the easiest way to keep everything running.

1.  **Start both processes**:
    ```bash
    pm2 start ecosystem.config.js
    ```

2.  **Save the process list** (so they restart on reboot):
    ```bash
    pm2 save
    pm2 startup
    ```

### Option B: Using npm scripts (Manual)

If you don't use PM2, you'll need to run these in separate terminal sessions or use a tool like `screen` or `tmux`.

1.  **Start the Web App**:
    ```bash
    npm start
    ```
    The app will be available at `http://localhost:3000`.

2.  **Start the Background Worker**:
    ```bash
    npm run worker
    ```
    This process checks for pending downloads and processes them.

## 7. Troubleshooting

### "SqliteError: no such table: users"
The database hasn't been initialized. Run `npm run init-db`.

### Downloads stuck in "Pending"
The background worker is not running. Make sure you started it using `pm2 start ecosystem.config.js` or `npm run worker`.

### "ENOENT: no such file or directory"
Check your `.env` file. The `DOWNLOAD_DIR` path might be incorrect or the directory might not exist.
- On macOS: `/Users/username/Downloads`
- On Linux: `/home/username/downloads`

### Permission Errors
Ensure the user running the node processes has read/write access to:
- The application directory
- The database directory (`/home/downloader-data/` by default)
- The download directory
