terraform {
  # Версия terraform
  required_version = "0.12.16"
}

provider "google" {
  # Версия провайдера
  version = "2.5.0"

  # ID проекта
  project = var.project
  region  = var.region
}

resource "google_compute_instance" "app" {
  name         = "reddit-app-terraform${count.index}"
  count        = var.instance_count
  machine_type = "g1-small"
  zone         = "europe-west1-b"
  tags         = ["reddit-app"]

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"
    #network = google_compute_network.vpc_network.self_link
    # использовать ephemeral IP для доступа из Интернет
    access_config {
    }
  }

  metadata = {
    # путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    host        = self.network_interface[0].access_config[0].nat_ip
    private_key = file("~/.ssh/appuser")
  }
  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }
  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }
}

#resource "google_compute_network" "vpc_network" {
#  name                    = "terraform-network"
#  auto_create_subnetworks = "true"
#}


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

