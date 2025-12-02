# Database Location

The application database is stored **outside the project directory** to prevent data loss during:
- Git operations (`git pull`, `git reset`, etc.)
- Project cleanup

## Default Location

By default, the database is stored at:
```
../downloader-data/downloader.db
```

This is one level up from your project directory.

## Custom Location

You can specify a custom location using the `DATA_DIR` environment variable:

```bash
# In your .env file
DATA_DIR=/path/to/your/data/directory
```

Or when running the application:
```bash
DATA_DIR=/mnt/storage/downloader-data swift run Run serve
```

## Important Notes

1. **Backup**: The database contains users, sessions, downloads, and settings. Make sure to back it up regularly.

2. **Permissions**: Ensure the application has read/write permissions to the data directory.

3. **Migration**: If you already have data in `sqlite.db` in the project root, you should:
   ```bash
   # Move existing database to new location
   mkdir -p ../downloader-data
   mv sqlite.db ../downloader-data/downloader.db
   ```

4. **First Run**: On first run, the application will automatically create the data directory if it doesn't exist.

## Database Files

The SQLite database may create additional files:
- `downloader.db` - Main database file
- `downloader.db-shm` - Shared memory file (temporary)
- `downloader.db-wal` - Write-ahead log (temporary)

All these files are automatically managed by SQLite and should be kept together.
