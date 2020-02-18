resource "google_compute_instance" "app" {
  name = "reddit-app"
  machine_type = "g1-small"
  zone = var.zone
  tags = ["reddit-app"]
  
  boot_disk {
    initialize_params { image = var.app_disk_image }
  }
  
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }

  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  
  connection {
    type        = "ssh"
    host        = google_compute_address.app_ip.address
    user        = "appuser"
    agent       = false
    private_key = file("~/.ssh/appuser")
  }
  
  provisioner "file" {
    source      = "${path.module}/files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    script = "${path.module}/files/deploy.sh"
  }

  provisioner "remote-exec" {
#   inline = ["echo export DATABASE_URL=\"${var.mongod_ip}\" >> ~/.profile"]
    inline = [
      "echo 'export DATABASE_URL=${var.db_addr.0}' >> ~/.profile",
      "export DATABASE_URL=${var.db_addr.0}",
      "sudo systemctl restart puma.service",
    ]
  }

}

resource "google_compute_address" "app_ip" { name = "reddit-app-ip" }

resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-app"]
}

