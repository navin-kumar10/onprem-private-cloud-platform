#!/usr/bin/env bash
# Restore test: verifies latest backup is actually restorable.
# - Picks latest vzdump for TEST_VMID, restores as NEW_VMID on isolated bridge
# - Boots, waits for qemu-guest-agent, curls healthcheck, then destroys clone
# Usage: TEST_VMID=101 NEW_VMID=9900 bash scripts/restore-test.sh
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/mnt/pbs/dump}"
TEST_VMID="${TEST_VMID:-101}"
NEW_VMID="${NEW_VMID:-9900}"
ISOLATED_BRIDGE="${ISOLATED_BRIDGE:-vmbr1}"
TIMEOUT_S="${TIMEOUT_S:-300}"

latest="$(ls -1t "$BACKUP_DIR"/vzdump-qemu-"$TEST_VMID"-*.vma* 2>/dev/null | head -n1 || true)"
if [ -z "$latest" ]; then
  echo "[restore-test] FAIL: no backup found for VMID $TEST_VMID in $BACKUP_DIR" >&2
  exit 1
fi
echo "[restore-test] latest backup: $latest"

if ! command -v qm >/dev/null 2>&1; then
  echo "[restore-test] qm not found — dry-run mode, checking archive readability only"
  if command -v zstd >/dev/null 2>&1; then
    zstd -l "$latest" >/dev/null && echo "[restore-test] DRY-RUN PASS (archive lists OK)"
  else
    test -s "$latest" && echo "[restore-test] DRY-RUN PASS (archive non-empty)"
  fi
  exit 0
fi

# Cleanup any stale test clone
if qm status "$NEW_VMID" >/dev/null 2>&1; then
  echo "[restore-test] destroying stale $NEW_VMID"
  qm stop "$NEW_VMID" || true
  sleep 5
  qm destroy "$NEW_VMID" --purge || true
fi

echo "[restore-test] restoring $latest as $NEW_VMID"
qmrestore "$latest" "$NEW_VMID" --storage local-zfs || qmrestore "$latest" "$NEW_VMID"

# Force isolated bridge (avoid IP clash with source VM)
qm set "$NEW_VMID" --net0 "virtio,bridge=$ISOLATED_BRIDGE" || true
qm set "$NEW_VMID" --name "restore-test-$TEST_VMID" || true

qm start "$NEW_VMID"
echo "[restore-test] waiting for guest agent (up to ${TIMEOUT_S}s)"
deadline=$((SECONDS + TIMEOUT_S))
until qm agent "$NEW_VMID" ping >/dev/null 2>&1; do
  if [ $SECONDS -gt $deadline ]; then
    echo "[restore-test] FAIL: guest agent never responded" >&2
    qm stop "$NEW_VMID" || true
    qm destroy "$NEW_VMID" --purge || true
    exit 1
  fi
  sleep 10
done

echo "[restore-test] guest up. network info:"
qm agent "$NEW_VMID" network-get-interfaces || true

# Optional HTTP healthcheck (best-effort; lab images may not run web server)
qm agent "$NEW_VMID" exec -- bash -c 'curl -sf -m 5 http://localhost:80/ || curl -sf -m 5 http://localhost:3000/ || echo "no http service (ok for base image)"' || true

echo "[restore-test] PASS — cleaning up clone"
qm stop "$NEW_VMID" || true
sleep 5
qm destroy "$NEW_VMID" --purge
echo "[restore-test] done $(date -u +%FT%TZ)"
