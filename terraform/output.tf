output "vm-puplic-ip" {
  description = "VM public ip to be used in ansible playbook"
  value       = google_compute_instance.management-vm.network_interface.0.access_config.0.nat_ip
}
