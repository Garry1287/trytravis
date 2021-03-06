variable region {
  description = "Region"
  # Значение по умолчанию
  default = "europe-west1"
}
variable zone {
  description = "Zone"
  # Значение по умолчанию
  default = "europe-west1-b"
}
variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
  default = "~/.ssh/appuser.pub"
}
variable app_disk_image {
  description = "Disk image for reddit app"
  default = "reddit-app-base"
}
variable mongod_ip {
  description = "mongod internal ip"
  default = "module.db.mongod_ip.value"
}
#variable db_external_ip {
#  description = "database internal ip"
#  default = "module.db.db_external_ip.value"
#}
variable db_addr {
  description = "database internal ip"
#  default = "module.db.internal_ip.value"
}