# Proxmox Setup

Tested against Proxmox VE 8.x (Debian 12 base).

## 1. Install Proxmox

1. Flash PVE 8 ISO (Ventoy/Rufus/balenaEtcher), boot server, install to NVMe mirror.
2. Set management IP, gateway, DNS. Example: `192.168.1.10/24`, gw `192.168.1.1`.
3. Reboot, browse to `https://192.168.1.10:8006`. Accept self-signed cert (replace later).
4. No-subscription nag (lab only):
   ```bash
   sed -i 's/NotFound/Active/' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
   systemctl restart pveproxy
   ```
5. Update:
   ```bash
   apt update && apt full-upgrade -y && reboot
   ```

## 2. Storage

- `local-zfs` or `local-lvm` for VM disks (thin provision). Enable discard/SSD emulation.
- Backups: separate disk/NAS mounted at `/mnt/pbs`, or a PBS LXC/VM (`10.10.0.5`).
- Enablealik `Datacenter > Storage > Add > PBS/NFS`.

## 3. Networking

Create `vmbr1` (isolated lab bridge, no physical port):

```bash
cat >> /etc/network/interfaces <<'EOF'
auto vmbr1
iface vmbr1 inet static
  address 10.10.0.1/24
  bridge-ports none
  bridge-stp off
  bridge-fd 0
EOF
ifup vmbr1
```

- `vmbr0`: WAN/LAN (DHCP or static, bound to NIC).
- `vmbr1`: `10.10.0.0/24` lab network. VMs get static IPs via Terraform cloud-init + internal DNS on `tools`.
- Firewall: `Datacenter > Firewall`, default DROP; allow 8006 (management, VPN-only), 22, 80, 443.

## 4. Cloud-init Template

```bash
# On PVE host
cd /var/lib/vz/template/iso
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2.img
qm create 9000 --name debian-12-cloud --memory 2048 --cores 2 --net0 virtio,bridge=vmbr1
qm importdisk 9000 debian-12-generic-amd64.qcow2.img local-zfs
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-9000-disk-0
qm set 9000 --ide2 local:cloudinit --boot c --bootdisk scsi0 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1 --template 1
# Note file ID for terraform: e.g. local:iso/debian-12-generic-amd64.img
# Or clone template to a reusable template volume and reference it.
```

Set `pm_template_file_id` in `terraform.tfvars` accordingly. The `bpg/proxmox` provider clones this disk for each VM.

## 5. API Token for Terraform

1. `Datacenter > Access > Users > Add` service user `terraform@pve`.
2. `Permissions > Add`: `PVEVMAdmin`, `PVEDatastoreAdmin`, `PVEPoolAdmin` on `/` (tighten to pool in production).
3. `API Tokens > Add`, copy `user@realm!tokenid=secret` into `pm_api_token` (never commit).
4. Test: `terraform init && terraform plan`.

## 6. SSH + Ansible

- Generate ed25519 key, add pubkey to `vm_ssh_key` var. Cloud-init creates `ops` user.
- `ansible -i ansible/inventory.ini all -m ping` should succeed after `terraform apply`.

## 7. Snapshots Before Changes

```bash
qm snapshot 100 pre-ansible --snapname pre-ansible
```

Ansible re-runs are idempotent; roll back with `qm rollback 100 pre-ansible` if needed.
