# Proxmox / Debian Deployment Guide

This guide explains how to deploy the Downloader App on a Proxmox Debian LXC Container.

## 1. Create Debian CT
1.  In Proxmox, create a new CT.
2.  Template: `debian-12-standard`.
3.  Resources: 2GB RAM, 2 Cores recommended.
4.  Network: Static IP recommended.

## 2. Install Dependencies

Access the CT console and run:

```bash
apt update && apt upgrade -y
apt install -y curl git unzip clang libsqlite3-dev libpython3-dev
```

### Install Swift
Debian 12 (Bookworm) instructions:

```bash
# Download Swift 6.0.2 (or latest)
wget https://download.swift.org/swift-6.0.2-release/ubuntu2204/swift-6.0.2-RELEASE/swift-6.0.2-RELEASE-ubuntu22.04.tar.gz

# Extract
tar xzf swift-6.0.2-RELEASE-ubuntu22.04.tar.gz
mv swift-6.0.2-RELEASE-ubuntu22.04 /usr/share/swift

# Add to PATH
echo "export PATH=/usr/share/swift/usr/bin:$PATH" >> ~/.bashrc
source ~/.bashrc

# Verify
swift --version
```

### Install Node.js (for Frontend)
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
```

### Install PM2 (Process Manager)
```bash
npm install -g pm2
```

## 3. Deploy Application

### Clone Repository
```bash
git clone <your-repo-url> /opt/downloader
cd /opt/downloader
```

### Setup Backend
```bash
cd backend
swift build -c release
```

### Setup Frontend
```bash
cd ..
npm install
npm run build
```

## 4. Configure Systemd Services

### Backend Service
Create `/etc/systemd/system/downloader-backend.service`:

```ini
[Unit]
Description=Downloader Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/downloader/backend
ExecStart=/usr/share/swift/usr/bin/swift run -c release Run serve --hostname 0.0.0.0 --port 8080
Restart=always
Environment=DATA_DIR=/opt/downloader-data

[Install]
WantedBy=multi-user.target
```

### Frontend Service (via PM2)
```bash
cd /opt/downloader
pm2 start npm --name "downloader-frontend" -- start
pm2 save
pm2 startup
```

## 5. Start Services
```bash
# Create data directory
mkdir -p /opt/downloader-data

# Start Backend
systemctl enable downloader-backend
systemctl start downloader-backend

# Check status
systemctl status downloader-backend
```

Your app should now be accessible at `http://<CT-IP>:3000`.
