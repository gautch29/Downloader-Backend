# Remote PostgreSQL Setup Guide

Since you are running PostgreSQL on a separate Proxmox Container (CT), you need to configure it to accept connections from your Backend CT.

## 1. Access the Database Container
Open the console of your **PostgreSQL CT** (or SSH into it).

## 2. Create User and Database
Switch to the postgres user and access the shell:
```bash
su - postgres
psql
```

Run these SQL commands (change `myuser` and `mypassword` to what you want):
```sql
-- Create the user
CREATE USER downloader WITH PASSWORD 'secure_password_here';

-- Create the database
CREATE DATABASE downloader_db OWNER downloader;

-- Exit psql
\q
```

## 3. Enable Remote Access
You need to tell Postgres to listen on all IP addresses, not just localhost.

### Edit `postgresql.conf`
Find the file (usually in `/etc/postgresql/15/main/` or similar version):
```bash
nano /etc/postgresql/15/main/postgresql.conf
```
Find `listen_addresses` and change it to:
```conf
listen_addresses = '*'
```

### Edit `pg_hba.conf`
Edit the client authentication file:
```bash
nano /etc/postgresql/15/main/pg_hba.conf
```
Add this line at the end to allow the Backend CT IP to connect (replace `192.168.1.100` with your **Backend CT IP**, or use `0.0.0.0/0` to allow any IP for testing):
```conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    downloader_db   downloader      192.168.1.100/32        scram-sha-256
```
*(If you are unsure of the IP, you can use `0.0.0.0/0` temporarily, but limit it later for security).*

## 4. Restart PostgreSQL
Exit the `postgres` user check (exit to root) and restart the service:
```bash
exit
systemctl restart postgresql
```

## 5. Verify & Connect
In your **Backend CT** (the one running the Go app), update your `.env` file:
```env
DATABASE_URL=postgres://downloader:secure_password_here@<POSTGRES_CT_IP>:5432/downloader_db
```
*(Replace `<POSTGRES_CT_IP>` with the IP address of the database container)*.
