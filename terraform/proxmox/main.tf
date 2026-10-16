terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = var.pm_api_token
  insecure  = var.pm_tls_insecure
  ssh {
    agent    = true
    username = var.pm_ssh_username
  }
}

resource "proxmox_virtual_environment_vm" "nodes" {
  for_each = var.vms

  name        = each.key
  description = "Managed by Terraform - onprem-private-cloud-platform"
  tags        = ["terraform", "lab", each.value.role]
  node_name   = var.pm_node
  vm_id       = each.value.vmid
  started     = true
  on_boot     = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = var.pm_datastore
    file_id      = var.pm_template_file_id
    interface    = "scsi0"
    size         = each.value.disk_gb
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge  = var.pm_bridge_lan
    model   = "virtio"
    vlan_id = var.pm_vlan_id
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.pm_datastore
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.pm_gateway
      }
    }
    dns {
      servers = var.pm_dns_servers
    }
    user_account {
      username = var.vm_username
      keys     = [var.vm_ssh_key]
    }
  }
}
