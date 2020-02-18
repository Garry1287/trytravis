resource "google_compute_instance" "db" {
  name = "reddit-db"
  machine_type = "g1-small"
  zone = var.zone
  tags = ["reddit-db"]
  
  boot_disk {
    initialize_params { image = var.db_disk_image }
  }
  
  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  
  connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = file("~/.ssh/appuser")
    host = self.network_interface[0].access_config[0].nat_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf",
      "sudo systemctl restart mongod"
    ]
  }
}

resource "google_compute_firewall" "firewall_mongo" {
  name = "allow-mongo-default"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-db"]
  source_tags = ["reddit-app"]
}
