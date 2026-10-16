output "vm_names" {
  description = "VM names managed by Terraform"
  value       = [for k, v in proxmox_virtual_environment_vm.nodes : v.name]
}

output "vm_ipv4" {
  description = "Static IPs assigned via cloud-init"
  value       = { for k, v in var.vms : k => v.ip }
}

output "vm_ids" {
  description = "Proxmox VMIDs"
  value       = { for k, v in proxmox_virtual_environment_vm.nodes : k => v.vm_id }
}
