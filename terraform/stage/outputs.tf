#output "app_external_ip" {
  #value = google_compute_instance.app.network_interface.0.access_config.0.assigned_nat_ip
 # value = google_compute_instance.app[*].network_interface[*].access_config[0].nat_ip
#}

#output "lb-static-ip" {
#  value = google_compute_global_address.lb-static-ip.ip_address
#  value = google_compute_global_forwarding_rule.default.ip_address
#  value = google_compute_global_address.lb-static-ip.address
#  value = google_compute_forwarding_rule.http-frontend.ip_address
#}

output "app_external_ip" {
  value = "${module.app.app_external_ip}"
}

output "db_external_ip" {
  value = "${module.db.db_external_ip}"
}

output "db_addr" {
  value = "${module.db.internal_ip}"
}