variable "pm_api_url" {
  description = "Proxmox API endpoint, e.g. https://192.168.1.10:8006/"
  type        = string
}

variable "pm_api_token" {
  description = "Proxmox API token 'user@realm!tokenid=secret'"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Skip TLS verify for self-signed PVE cert"
  type        = bool
  default     = true
}

variable "pm_ssh_username" {
  description = "SSH user for Proxmox provider operations"
  type        = string
  default     = "root"
}

variable "pm_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve-01"
}

variable "pm_datastore" {
  description = "Storage for VM disks (e.g. local-zfs, local-lvm)"
  type        = string
  default     = "local-zfs"
}

variable "pm_template_file_id" {
  description = "Cloud-init template file ID, e.g. local:iso/debian-12-generic-amd64.img"
  type        = string
}

variable "pm_bridge_lan" {
  description = "Bridge for lab network"
  type        = string
  default     = "vmbr1"
}

variable "pm_vlan_id" {
  description = "VLAN ID (0 = untagged)"
  type        = number
  default     = 0
}

variable "pm_gateway" {
  description = "Gateway for lab network"
  type        = string
  default     = "10.10.0.1"
}

variable "pm_dns_servers" {
  description = "DNS servers for VMs"
  type        = list(string)
  default     = ["10.10.0.10", "1.1.1.1"]
}

variable "vm_username" {
  description = "Default VM user (cloud-init)"
  type        = string
  default     = "ops"
}

variable "vm_ssh_key" {
  description = "SSH public key for cloud-init user"
  type        = string
}

variable "vms" {
  description = "VM matrix"
  type = map(object({
    vmid      = number
    role      = string
    ip        = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
  default = {
    tools = {
      vmid = 100, role = "tools", ip = "10.10.0.10", cores = 4, memory_mb = 16384, disk_gb = 100
    }
    dev-01 = {
      vmid = 101, role = "dev", ip = "10.10.0.21", cores = 4, memory_mb = 16384, disk_gb = 80
    }
    dev-02 = {
      vmid = 102, role = "dev", ip = "10.10.0.22", cores = 4, memory_mb = 16384, disk_gb = 80
    }
    test-01 = {
      vmid = 103, role = "test", ip = "10.10.0.31", cores = 4, memory_mb = 16384, disk_gb = 80
    }
    staging-01 = {
      vmid = 104, role = "staging", ip = "10.10.0.41", cores = 4, memory_mb = 16384, disk_gb = 80
    }
  }
}
