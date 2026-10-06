#!/bin/bash
set -euo pipefail

# Production Automated Installer for Node Exporter
# Architecture: AMD64 / ARM64 auto-detection
# Version: 1.8.2

NODE_EXPORTER_VERSION="1.8.2"

echo "[INFO] Detecting system architecture..."
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "[ERROR] Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "[INFO] Creating node_exporter system user..."
if ! id "node_exporter" &>/dev/null; then
  sudo useradd --no-create-home --shell /bin/false node_exporter
fi

echo "[INFO] Downloading Node Exporter v${NODE_EXPORTER_VERSION}..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
curl -sSL "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" -o node_exporter.tar.gz
tar -xzf node_exporter.tar.gz

echo "[INFO] Installing binary to /usr/local/bin..."
sudo cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
sudo chmod 755 /usr/local/bin/node_exporter

echo "[INFO] Cleaning temporary files..."
rm -rf "$TMP_DIR"

echo "[INFO] Configuring systemd service..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=0.0.0.0:9100 \
  --collector.systemd \
  --collector.processes \
  --collector.filesystem.mount-points-exclude="^/(sys|proc|dev|host|etc)($$|/)"

Restart=always
RestartSec=3s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Reloading systemd daemon and starting node_exporter..."
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl restart node_exporter

echo "[INFO] Verifying node_exporter status and metrics endpoint..."
sleep 2
if curl -s "http://127.0.0.1:9100/metrics" | grep -q "node_cpu_seconds_total"; then
  echo "[SUCCESS] Node Exporter successfully installed and exporting host metrics on port 9100!"
else
  echo "[ERROR] Metrics endpoint verification failed."
  sudo systemctl status node_exporter
  exit 1
fi
