# API Documentation

Base URL: `http://localhost:8080/api`

## Authentication

### Login
**POST** `/auth/login`

**Request Body:**
```json
{
  "username": "admin",
  "password": "password"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "username": "admin"
  }
}
```
*Sets a `session_id` cookie.*

### Logout
**POST** `/auth/logout`

**Response:**
*Clears the `session_id` cookie.*

---

## Downloads

### List Downloads
**GET** `/downloads`

**Response:**
```json
[
  {
    "id": 1,
    "url": "https://1fichier.com/...",
    "filename": "movie.mkv",
    "status": "completed",
    "size": 1024000,
    "progress": 100,
    "created_at": "2023-10-27T10:00:00Z"
  }
]
```

### Add Download
**POST** `/downloads`

**Request Body:**
```json
{
  "url": "https://1fichier.com/...",
  "customFilename": "My Movie.mkv",
  "targetPath": "/movies"
}
```

### Delete Download
**DELETE** `/downloads/:id`

---

## Settings

### Get Settings
**GET** `/settings`

**Response:**
```json
{
  "plexUrl": "http://192.168.1.10:32400",
  "plexToken": "xyz..."
}
```

### Update Settings
**PUT** `/settings`

**Request Body:**
```json
{
  "plexUrl": "http://192.168.1.10:32400",
  "plexToken": "new_token"
}
```
