#output "app_external_ip" {
  #value = google_compute_instance.app.network_interface.0.access_config.0.assigned_nat_ip
  #value = google_compute_instance.app[*].network_interface[*].access_config[0].nat_ip
#}
output "db_external_ip" {
  value = google_compute_instance.db.network_interface.0.access_config.0.assigned_nat_ip
}

output "mongod_ip" {
  value = google_compute_instance.db.network_interface.0.network_ip
}
