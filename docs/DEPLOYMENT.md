# Deployment Guide

This guide covers how to set up, configure, and run the Downloader Backend in a production environment, specifically focusing on Linux systems (Debian/Ubuntu/Proxmox).

## Prerequisites

-   **Linux server** (Debian 12 / Ubuntu 22.04 recommended)
-   **Swift 6.0+** installed
-   **Systemd** (standard on most modern Linux distros)

## 1. Installation

### Install Swift
If you haven't installed Swift yet, follow these steps (example for Ubuntu 22.04 / Debian 12):

```bash
# Install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git unzip clang libsqlite3-dev libpython3-dev

# Download Swift (check swift.org for the latest release URL)
wget https://download.swift.org/swift-6.0.2-release/ubuntu2204/swift-6.0.2-RELEASE/swift-6.0.2-RELEASE-ubuntu22.04.tar.gz

# Extract
tar xzf swift-6.0.2-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0.2-RELEASE-ubuntu22.04 /usr/share/swift

# Add to PATH
echo "export PATH=/usr/share/swift/usr/bin:$PATH" >> ~/.bashrc
source ~/.bashrc

# Verify
swift --version
```

### Clone and Build
Clone the repository and build the backend in release mode.

```bash
git clone <your-repo-url> downloader
cd downloader/backend
swift build -c release
```

## 2. Configuration

The application uses environment variables for configuration. You can set these in the systemd service file or export them in your shell.

-   `DATA_DIR`: Path to store the database and downloads (default: `../downloader-data`).
-   `PORT`: Server port (default: 8080).
-   `ONEFICHIER_API_KEY`: Your 1fichier API key.

## 3. Systemd Service Setup

To run the backend as a background service, create a systemd unit file.

1.  **Copy the Service File**
    Copy the provided `downloader-backend.service` file to `/etc/systemd/system/`.

    ```bash
    sudo cp downloader-backend.service /etc/systemd/system/
    ```

2.  **Edit the Service File**
    Adjust the paths and user to match your installation.

    ```bash
    sudo nano /etc/systemd/system/downloader-backend.service
    ```

    -   `User`: Change to your user (e.g., `root` or a dedicated user).
    -   `WorkingDirectory`: Path to where you cloned the repo (e.g., `/opt/downloader/backend`).
    -   `ExecStart`: Path to the `Run` executable.
        > **Tip:** Run `swift build -c release --show-bin-path` to find the exact path.
    -   `Environment`: Set `DATA_DIR` and `ONEFICHIER_API_KEY`.

3.  **Reload and Start**

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable downloader-backend
    sudo systemctl start downloader-backend
    ```

4.  **Check Status**

    ```bash
    sudo systemctl status downloader-backend
    ```

## 4. Viewing Logs

You can view the application logs using `journalctl`.

```bash
# View real-time logs
sudo journalctl -u downloader-backend -f
```

## 5. Updating

To update the application:

1.  Stop the service: `sudo systemctl stop downloader-backend`
2.  Pull latest changes: `git pull`
3.  Rebuild: `swift build -c release`
4.  Start the service: `sudo systemctl start downloader-backend`
