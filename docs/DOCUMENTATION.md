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

**dl.flgr.fr** is a premium 1fichier download manager built with Next.js 16, featuring:
- Secure user authentication with session management
- Queue-based download system with real-time progress tracking
- Plex Media Server integration for automatic library scanning
- Bilingual interface (English/French)
- Apple-inspired "liquid glass" UI with system theme support
- Path shortcuts for organized file management

**Tech Stack:**
- **Framework**: Next.js 16.0.3 (App Router, React Server Components)
- **Database**: SQLite with Drizzle ORM
- **Authentication**: bcrypt + session-based auth
- **Styling**: Tailwind CSS with custom Apple-inspired design system
- **HTTP Client**: ky (for 1fichier API and downloads)
- **Process Manager**: PM2 (for production deployment)

---

## Architecture

### Application Structure

```
/app                    # Next.js App Router pages
  /login               # Authentication page
  /settings            # User settings & Plex configuration
  page.tsx             # Home page (server component)
  home-client.tsx      # Home page UI (client component)
  layout.tsx           # Root layout with i18n provider
  globals.css          # Global styles & design system

/components            # Reusable UI components
  /ui                  # shadcn/ui components
  download-card.tsx    # Download progress card
  header-client.tsx    # Navigation header
  path-selector.tsx    # Path selection dropdown
  path-shortcuts-modal.tsx  # Path management modal

/lib                   # Core business logic
  auth.ts              # Authentication utilities
  session.ts           # Session management
  db.ts                # Database connection
  1fichier.ts          # 1fichier API client
  plex.ts              # Plex integration
  settings.ts          # App settings management
  path-config.ts       # Path shortcuts management
  i18n.tsx             # Internationalization

/db                    # Database schema
  schema.ts            # Drizzle ORM schema definitions

/scripts               # CLI utilities
  add-user.ts          # Create new users
  list-users.ts        # List all users
  delete-user.ts       # Remove users

worker.ts              # Background download processor
middleware.ts          # Route protection middleware
ecosystem.config.js    # PM2 configuration
```

### Process Architecture

The application runs as **two separate processes** managed by PM2:

1. **Web Server** (`downloader-web`):
   - Next.js application serving the UI
   - Handles user authentication
   - Manages download queue (adds downloads to database)
   - Serves real-time download status

2. **Worker Process** (`downloader-worker`):
   - Polls database every 5 seconds for pending downloads
   - Processes downloads sequentially (one at a time)
   - Updates progress in real-time
   - Triggers Plex library scans on completion

---

## Database Schema

**Database**: SQLite (`local.db`)  
**ORM**: Drizzle ORM

### Tables

#### `downloads`
Stores download queue and status.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key (auto-increment) |
| `url` | TEXT | 1fichier URL (required) |
| `filename` | TEXT | Detected filename from server |
| `custom_filename` | TEXT | User-specified filename override |
| `target_path` | TEXT | Download destination path |
| `status` | TEXT | `pending`, `downloading`, `completed`, `error` |
| `progress` | INTEGER | Download progress (0-100) |
| `size` | INTEGER | File size in bytes |
| `speed` | INTEGER | Download speed in bytes/sec |
| `eta` | INTEGER | Estimated seconds remaining |
| `error` | TEXT | Error message if status is `error` |
| `created_at` | TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMP | Last update timestamp |

#### `users`
Stores user accounts.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key (auto-increment) |
| `username` | TEXT | Unique username (required) |
| `password_hash` | TEXT | bcrypt hash (required) |
| `created_at` | TIMESTAMP | Account creation timestamp |

#### `sessions`
Stores active user sessions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | Primary key (64-char hex string) |
| `user_id` | INTEGER | Foreign key to `users.id` (CASCADE DELETE) |
| `expires_at` | TIMESTAMP | Session expiration time |
| `created_at` | TIMESTAMP | Session creation timestamp |

#### `settings`
Stores application-wide settings (singleton table).

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key (auto-increment) |
| `plex_url` | TEXT | Plex Media Server URL |
| `plex_token` | TEXT | Plex authentication token |
| `updated_at` | TIMESTAMP | Last update timestamp |

---

## Security & Authentication

### Password Security

**Hashing Algorithm**: bcrypt  
**Salt Rounds**: 10

```typescript
// Password hashing (lib/auth.ts)
async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

// Password verification
async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}
```

**Password Storage**:
- Passwords are **never** stored in plaintext
- Only bcrypt hashes are stored in the `users.password_hash` column
- bcrypt automatically generates unique salts for each password
- Hashes are one-way and cannot be reversed

### Session Management

**Session ID Generation**: Cryptographically secure random 64-character hex string

```typescript
// Session creation (lib/auth.ts)
const sessionId = randomBytes(32).toString('hex'); // 256 bits of entropy
```

**Session Storage**:
- Session IDs stored in HTTP-only cookies
- Cookie name: `session`
- Cookie attributes:
  - `httpOnly: true` - Prevents JavaScript access (XSS protection)
  - `secure: false` - Allows HTTP (for local network deployment)
  - `sameSite: 'lax'` - CSRF protection
  - `maxAge: 2592000` - 30 days
  - `path: '/'` - Available site-wide

**Session Duration**: 30 days  
**Session Validation**: On every request via middleware

```typescript
// Middleware validates session (middleware.ts)
const userId = await getSession();
if (!userId) {
  return NextResponse.redirect(new URL('/login', request.url));
}
```

### Route Protection

**Protected Routes**: All routes except `/login`  
**Middleware**: `middleware.ts` intercepts all requests and validates sessions

**Flow**:
1. User accesses protected route
2. Middleware checks for `session` cookie
3. If missing → redirect to `/login`
4. If present → validate against database
5. If expired → delete session, redirect to `/login`
6. If valid → allow access

---

## Core Components

### 1. Download Manager (`worker.ts`)

**Purpose**: Background process that handles file downloads

**Process Flow**:
1. Poll database every 5 seconds for `status = 'pending'`
2. If found, update status to `downloading`
3. Request direct download link from 1fichier API
4. Stream file to disk with progress tracking
5. Update database every 2 seconds with progress percentage
6. On completion:
   - Set `status = 'completed'`
   - Trigger Plex library scan
7. On error:
   - Set `status = 'error'`
   - Store error message

**Progress Tracking**:
```typescript
onDownloadProgress: async (progress) => {
  const progressPercent = Math.floor(progress.percent * 100);
  if (now - lastProgressUpdate > 2000) {
    await db.update(downloads).set({ progress: progressPercent });
  }
}
```

**Permission Handling**:
- If target directory is not writable, automatically falls back to default `DOWNLOAD_DIR`
- Attempts to create directories with `0o777` permissions
- Logs detailed permission errors for debugging

### 2. 1fichier API Client (`lib/1fichier.ts`)

**Purpose**: Interface with 1fichier premium API

**Configuration**:
- API Key: `process.env.ONEFICHIER_API_KEY`
- Endpoint: `https://api.1fichier.com/v1/download/get_token.cgi`

**Features**:
- IPv4 enforcement (prevents "IP Locked" errors on IPv6)
- URL sanitization (removes affiliate parameters)
- Error handling with detailed logging

**API Request**:
```typescript
POST https://api.1fichier.com/v1/download/get_token.cgi
Headers:
  Authorization: Bearer {API_KEY}
  Content-Type: application/json
Body:
  { "url": "https://1fichier.com/?xyz123" }
```

### 3. Plex Integration (`lib/plex.ts`)

**Purpose**: Automatically trigger Plex library scans after downloads complete

**Configuration**:
- Plex URL: Stored in `settings.plex_url`
- Plex Token: Stored in `settings.plex_token`

**Scan Trigger**:
```typescript
GET {PLEX_URL}/library/sections/all/refresh?X-Plex-Token={TOKEN}
```

**Behavior**:
- Triggered after every successful download
- Silently fails if Plex settings not configured
- 5-second timeout to prevent hanging

### 4. Path Shortcuts (`lib/path-config.ts`)

**Purpose**: Manage custom download destination shortcuts

**Storage**: JSON file at `config/paths.json`

**Default Shortcuts**:
```json
{
  "shortcuts": [
    { "id": "downloads", "name": "Downloads", "path": "" },
    { "id": "movies", "name": "Movies", "path": "/mnt/media/Movies" },
    { "id": "tv", "name": "TV Shows", "path": "/mnt/media/TV" },
    { "id": "music", "name": "Music", "path": "/mnt/media/Music" }
  ]
}
```

**Path Resolution**:
- Empty path (`""`) → Uses `DOWNLOAD_DIR` environment variable
- Absolute path (`/mnt/...`) → Used directly
- Relative path (`./Movies`) → Joined with `DOWNLOAD_DIR`

### 5. Internationalization (`lib/i18n.tsx`)

**Supported Languages**: English (en), French (fr)

**Implementation**:
- React Context for language state
- `useI18n()` hook provides `t()` translation function
- Language preference stored in localStorage

**Usage**:
```typescript
const { t, language, setLanguage } = useI18n();
<h1>{t('download.title')}</h1>
```

---

## API Integration

### 1fichier API

**Authentication**: Bearer token (API key)  
**Rate Limiting**: Managed by 1fichier (premium account)

**Endpoints Used**:
- `POST /v1/download/get_token.cgi` - Get direct download link

**Error Handling**:
- HTTP errors logged with full response body
- Network errors caught and logged
- Errors propagated to download queue (status = `error`)

---

## File Management

### Download Directory Structure

**Default Directory**: `./downloads` (configurable via `DOWNLOAD_DIR`)

**Path Resolution**:
1. User selects path shortcut or enters custom path
2. If absolute path → use directly
3. If relative path → join with `DOWNLOAD_DIR`
4. If empty → use `DOWNLOAD_DIR`

**Filename Detection**:
1. User-specified `customFilename` (highest priority)
2. Filename from 1fichier API response
3. `Content-Disposition` header from download response
4. URL path basename
5. Fallback: `file-{download.id}`

**Directory Creation**:
- Automatically creates missing directories
- Uses `recursive: true` for nested paths
- Sets permissions to `0o777` (configurable)

---

## Deployment

### Production Setup (PM2)

**Configuration**: `ecosystem.config.js`

```javascript
{
  apps: [
    {
      name: "downloader-web",
      script: "npm",
      args: "start",
      env: { NODE_ENV: "production", PORT: 3000 }
    },
    {
      name: "downloader-worker",
      script: "npx",
      args: "tsx worker.ts",
      env: { NODE_ENV: "production" },
      env_file: ".env"
    }
  ]
}
```

**Deployment Steps**:
```bash
# 1. Install dependencies
npm install

# 2. Build Next.js app
npm run build

# 3. Start PM2 processes
pm2 start ecosystem.config.js

# 4. Save PM2 configuration
pm2 save

# 5. Enable auto-start on boot
pm2 startup
```

**PM2 Commands**:
```bash
pm2 status                    # View process status
pm2 logs                      # View logs
pm2 restart all               # Restart both processes
pm2 stop downloader-worker    # Stop worker only
pm2 delete all                # Remove all processes
```

### Environment Variables

**Required**:
- `ONEFICHIER_API_KEY` - 1fichier premium API key

**Optional**:
- `DOWNLOAD_DIR` - Default download directory (default: `./downloads`)
- `PORT` - Web server port (default: `3000`)
- `DATABASE_URL` - SQLite database path (default: `./local.db`)

**Example `.env`**:
```env
ONEFICHIER_API_KEY=your_api_key_here
DOWNLOAD_DIR=/mnt/storage/downloads
PORT=3000
```

---

## Configuration

### User Management

**Create User**:
```bash
npm run add-user
# Prompts for username and password
```

**List Users**:
```bash
npm run list-users
```

**Delete User**:
```bash
npm run delete-user
# Prompts for username
```

### Plex Configuration

1. Navigate to **Settings** page
2. Enter **Plex URL** (e.g., `http://192.168.1.100:32400`)
3. Enter **Plex Token** ([How to find token](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/))
4. Click **Save Plex Settings**

### Path Shortcuts

1. Navigate to **Home** page
2. Click **Manage Shortcuts** button
3. Add custom paths (absolute or relative)
4. Shortcuts are saved to `config/paths.json`

---

## Design System

### Theme System

**Modes**: Light & Dark (automatic system detection)

**Color Palette**:
- **Light Mode**: White backgrounds with subtle blue tints
- **Dark Mode**: Dark grey (`#1D1D1F`) with blue-grey tints
- **Accent**: Apple Blue (`#0071E3` light, `#0A84FF` dark)

**Glass Effect**:
- `backdrop-blur-3xl` - Maximum blur for liquid glass effect
- 50-60% opacity backgrounds
- Multi-layer inset shadows for depth
- Gradient borders for refraction effect
- Top highlight overlay for light reflection

**Typography**: Apple system fonts (`-apple-system, BlinkMacSystemFont, ...`)

---

## Troubleshooting

### Common Issues

**1. Downloads stuck in "pending"**
- Check worker process: `pm2 logs downloader-worker`
- Verify 1fichier API key is valid
- Check network connectivity

**2. Permission errors**
- Worker automatically falls back to `DOWNLOAD_DIR`
- Check folder permissions: `ls -la /path/to/folder`
- Ensure worker process has write access

**3. Session expired immediately**
- Check system clock (sessions use timestamps)
- Verify database is writable
- Clear browser cookies and re-login

**4. Plex scan not triggering**
- Verify Plex URL and Token in Settings
- Check Plex server is accessible from worker process
- Review worker logs for Plex errors

---

## Security Best Practices

1. **Change default credentials** immediately after deployment
2. **Use HTTPS** in production (configure reverse proxy)
3. **Restrict network access** (firewall rules, VPN)
4. **Regular backups** of `local.db` and `config/paths.json`
5. **Monitor logs** for suspicious activity
6. **Keep dependencies updated** (`npm audit`, `npm update`)

---

## License & Credits

**Built with**:
- Next.js, React, Tailwind CSS
- Drizzle ORM, better-sqlite3
- bcrypt, ky, lucide-react

**Design**: Inspired by Apple's design language

---

*Documentation last updated: 2025-11-20*
