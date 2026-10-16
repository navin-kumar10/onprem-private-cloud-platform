#!/usr/bin/env bash
# Proxmox + Docker volume backup. Run nightly via cron/systemd on PVE or PBS host.
# Usage: BACKUP_DIR=/mnt/pbs/dump RETENTION_DAILY=7 bash scripts/backup.sh
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/mnt/pbs/dump}"
RETENTION_DAILY="${RETENTION_DAILY:-7}"
LOG_FILE="${LOG_FILE:-/var/log/lab-backup.log}"
VM_IDS="${VM_IDS:-100 101 102 103 104}"

mkdir -p "$BACKUP_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[backup] $(date -u +%FT%TZ) starting. dir=$BACKUP_DIR"

if command -v vzdump >/dev/null 2>&1; then
  for vmid in $VM_IDS; do
    echo "[backup] vzdump $vmid (snapshot mode)"
    vzdump "$vmid" --mode snapshot --compress zstd \
      --dumpdir "$BACKUP_DIR" --notes-template 'lab-{{guestname}}-{{vmid}}'
  done
  # Prune vzdump archives, keep N newest per VM
  for vmid in $VM_IDS; do
    ls -1t "$BACKUP_DIR"/vzdump-qemu-"$vmid"-*.vma.zst 2>/dev/null \
      | tail -n +"$((RETENTION_DAILY + 1))" | xargs -r rm -f --
  done
else
  echo "[backup] vzdump not found (not on PVE host?) — skipping VM dumps"
fi

# Docker volumes on tools node (run via ssh if remote)
TOOLS_HOST="${TOOLS_HOST:-10.10.0.10}"
if [ "${BACKUP_DOCKER:-1}" = "1" ]; then
  echo "[backup] docker volumes from $TOOLS_HOST"
  ssh -o StrictHostKeyChecking=accept-new "ops@$TOOLS_HOST" \
    'docker run --rm -v registry-data:/data:ro -v /tmp:/backup alpine tar czf /backup/registry-data.tgz -C /data .' || true
  scp -O "ops@$TOOLS_HOST:/tmp/registry-data.tgz" "$BACKUP_DIR/registry-data-$(date +%F).tgz" || true
fi

# Snapshot list for audit
if command -v qm >/dev/null 2>&1; then
  qm list || true
fi

echo "[backup] done $(date -u +%FT%TZ). contents:"
ls -lh "$BACKUP_DIR" | tail -n 20
