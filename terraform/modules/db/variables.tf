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
variable db_disk_image {
  description = "Disk image for reddit db"
  default = "reddit-db-base"
}
