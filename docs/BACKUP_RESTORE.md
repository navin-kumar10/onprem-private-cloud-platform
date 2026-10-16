# Backup & Restore Runbook

## What Is Backed Up

| Layer | Tool | Frequency | Destination | Retention |
|-------|------|-----------|-------------|-----------|
| VM images + cloud-init disks | `vzdump` snapshot mode | nightly 02:00 | `/mnt/pbs/dump` (PBS/NFS) | 7 daily / 4 weekly / 6 monthly |
| Docker volumes (`registry-data`, `gitea-data`, etc.) | `scripts/backup.sh` (tar → borg pattern) | nightly after vzdump | same dir `*.tgz` | same as above |
| k3s etcd (if k3s) | `k3s etcd-snapshot save` via cron | nightly | `/mnt/pbs/dump/etcd-*.db` | 7 daily |
| Proxmox host config | `/etc/pve`, `/etc/network/interfaces` git snapshot | on change | private gitea | git history |

## Nightly Job

On PVE host (or PBS VM), systemd timer or cron:

```bash
# /etc/cron.d/lab-backup
0 2 * * * root BACKUP_DIR=/mnt/pbs/dump bash /opt/onprem-private-cloud-platform/scripts/backup.sh
0 3 * * 0 root BACKUP_DIR=/mnt/pbs/dump bash /opt/onprem-private-cloud-platform/scripts/restore-test.sh
```

`scripts/backup.sh` env knobs: `BACKUP_DIR`, `RETENTION_DAILY`, `VM_IDS`, `TOOLS_HOST`, `BACKUP_DOCKER=1`, `LOG_FILE`.

## Restore: Full VM

```bash
# List archives
ls -lt /mnt/pbs/dump/vzdump-qemu-101-*.vma.zst | head
# Restore over existing (stopped) or as new VMID
qm stop 101 || true
qmrestore /mnt/pbs/dump/vzdump-qemu-101-2026_10_15.vma.zst 101 --storage local-zfs --force
qm start 101
```

Via PBS UI: `Datacenter > Backup > Restore`, pick snapshot, target storage `local-zfs`.

## Restore: Single File / Docker Volume

```bash
tar tzf /mnt/pbs/dump/registry-data-2026-10-15.tgz | head
# Restore to temp volume, diff, then swap
docker volume create registry-data-restore
docker run --rm -v registry-data-restore:/restore -v /mnt/pbs/dump:/backup alpine \
  tar xzf /backup/registry-data-2026-10-15.tgz -C /restore
```

## Restore Test (Monthly, Required)

`scripts/restore-test.sh` boots the latest backup as VMID `9900` on isolated `vmbr1`, waits for qemu-guest-agent, prints network info, then destroys the clone. Exit non-zero = page.

```bash
TEST_VMID=101 NEW_VMID=9900 ISOLATED_BRIDGE=vmbr1 bash scripts/restore-test.sh
echo $?  # 0 = PASS
```

Record result in Grafana annotation or `docs/restore-log.md`. If no `qm` binary (CI), script degrades to archive-readability dry-run.

## Disaster Scenarios

1. **Single VM corrupt** — `qmrestore` latest archive, re-run `ansible-playbook --limit <host>`.
2. **PVE host disk failure** — reinstall PVE 8, re-mount PBS datastore, `qmrestore` each VM, restore `/etc/pve` from git.
3. **Total site loss** — rebuild from this repo + offsite PBS sync (USB rotation or `proxmox-backup-client` to remote). RTO ~4h, RPO 24h by default.

## Verification Checklist

- [ ] `backup.sh` exits 0, archive sizes plausible (`ls -lh`).
- [ ] `restore-test.sh` exits 0 monthly.
- [ ] Prometheus `up==1` for all nodes post-restore.
- [ ] `curl -k https://registry.lab.home.arpa/v2/` returns 401 (auth challenge = alive).
- [ ] Offsite copy exists (rotate USB or remote sync weekly).
