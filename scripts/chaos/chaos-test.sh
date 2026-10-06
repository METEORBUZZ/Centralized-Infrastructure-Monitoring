#!/bin/bash
set -euo pipefail

# Chaos & Failure Simulation Scripts for SRE Testing
# Usage: ./chaos-test.sh [scenario]
# Scenarios:
#   cpu-stress       - Spikes CPU to 95% using dd/stress
#   memory-stress    - Fills memory to test memory alert
#   disk-stress      - Creates temporary dummy files to fill disk > 85%
#   stop-exporter    - Stops Node Exporter service to trigger HostDown alert
#   restore-exporter - Restores Node Exporter service

SCENARIO="${1:-help}"

case "$SCENARIO" in
  cpu-stress)
    echo "[CHAOS] Triggering high CPU utilization on all available cores for 6 minutes..."
    echo "[CHAOS] Expected: HostHighCpuLoad alert enters PENDING then FIRING state."
    for i in $(seq 1 $(nproc || echo 2)); do
      sha1sum /dev/zero &
    done
    PID=$!
    echo "[CHAOS] CPU stress background processes started. Run 'pkill sha1sum' to stop."
    ;;

  memory-stress)
    echo "[CHAOS] Triggering high memory utilization using python memory allocation..."
    echo "[CHAOS] Expected: HostHighMemoryUsage alert enters FIRING state."
    python3 -c "
import time
data = ' ' * (1024 * 1024 * 500) # Allocate ~500MB
print('Allocated 500MB RAM. Holding for 300 seconds...')
time.sleep(300)
" &
    ;;

  disk-stress)
    echo "[CHAOS] Simulating disk space exhaustion on root partition..."
    echo "[CHAOS] Expected: HostDiskSpaceFillingUp alert fires within evaluation interval."
    mkdir -p /tmp/chaos-disk
    dd if=/dev/zero of=/tmp/chaos-disk/stress_large_file.img bs=1M count=1024 status=progress || true
    echo "[CHAOS] 1GB dummy file written to /tmp/chaos-disk/."
    ;;

  cleanup-disk)
    echo "[CHAOS] Cleaning up simulated disk files..."
    rm -rf /tmp/chaos-disk
    echo "[CHAOS] Cleanup complete."
    ;;

  stop-exporter)
    echo "[CHAOS] Stopping Node Exporter (systemctl stop prometheus-node-exporter)..."
    echo "[CHAOS] Expected: HostDown alert (up == 0) triggers in Prometheus within 2 minutes."
    sudo systemctl stop prometheus-node-exporter || sudo systemctl stop node_exporter || true
    ;;

  restore-exporter)
    echo "[CHAOS] Restoring Node Exporter service..."
    sudo systemctl start prometheus-node-exporter || sudo systemctl start node_exporter || true
    echo "[CHAOS] Node exporter restored."
    ;;

  stop-workload-container)
    CONTAINER="${2:-simulated-workload-1}"
    echo "[CHAOS] Stopping container $CONTAINER..."
    docker stop "$CONTAINER"
    echo "[CHAOS] Container stopped. Target should transition to DOWN in Prometheus."
    ;;

  restore-workload-container)
    CONTAINER="${2:-simulated-workload-1}"
    echo "[CHAOS] Restoring container $CONTAINER..."
    docker start "$CONTAINER"
    echo "[CHAOS] Container restored. Target should transition to UP in Prometheus."
    ;;

  *)
    echo "Usage: $0 {cpu-stress|memory-stress|disk-stress|cleanup-disk|stop-exporter|restore-exporter|stop-workload-container|restore-workload-container}"
    exit 1
    ;;
esac
