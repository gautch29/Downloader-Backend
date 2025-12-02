# Systemd Setup Guide

This guide explains how to run the Downloader Backend as a systemd service on Linux (e.g., Debian, Ubuntu, Proxmox CT).

## Prerequisites

-   Linux server (Debian/Ubuntu recommended)
-   Swift installed (or the binary built)
-   `systemd` (standard on most modern Linux distros)

## Installation

1.  **Copy the Service File**
    Copy the `downloader-backend.service` file to `/etc/systemd/system/`.

    ```bash
    sudo cp downloader-backend.service /etc/systemd/system/
    ```

2.  **Edit the Service File**
    Open the file and adjust the paths and user to match your installation.

    ```bash
    sudo nano /etc/systemd/system/downloader-backend.service
    ```

    -   `User`: Change to your user (e.g., `root` or a dedicated user).
    -   `WorkingDirectory`: Path to where you cloned the repo.
    -   `ExecStart`: Path to the `Run` executable.
    -   `Environment`: Set `DATA_DIR` and `ONEFICHIER_API_KEY`.

3.  **Reload Systemd**
    Tell systemd to reload the configuration files.

    ```bash
    sudo systemctl daemon-reload
    ```

4.  **Enable and Start**
    Enable the service to start on boot, and start it now.

    ```bash
    sudo systemctl enable downloader-backend
    sudo systemctl start downloader-backend
    ```

5.  **Check Status**
    Verify the service is running.

    ```bash
    sudo systemctl status downloader-backend
    ```

## Viewing Logs

You can view the application logs using `journalctl`.

```bash
# View real-time logs
sudo journalctl -u downloader-backend -f

# View all logs
sudo journalctl -u downloader-backend
```

## Updating

To update the application:

1.  Stop the service: `sudo systemctl stop downloader-backend`
2.  Pull latest changes: `git pull`
3.  Rebuild: `swift build -c release`
4.  Start the service: `sudo systemctl start downloader-backend`
