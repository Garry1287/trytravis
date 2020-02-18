terraform {
  # Версия terraform
  required_version = "0.12.16"
}

resource "google_compute_instance_group" "instance-group-1" { 
    name  = "instance-group-1" 
    description = "Terraform test instance group" 
	# Количестов инстансов будет равно всем, которые создаются в main через count из переменных
    instances = google_compute_instance.app[*].self_link 

    named_port {
      name = "http"
      port = "9292"
    }
    lifecycle {
      create_before_destroy = true
    }
  
   zone = "europe-west1-b"
} 

resource "google_compute_global_address" "lb-static-ip" {
  name = "lb-static-ip"
  #External ip address
}

resource "google_compute_global_forwarding_rule" "http-frontend" {
  name       = "http-frontend"
  target     = google_compute_target_http_proxy.mybalancer-target-proxy.self_link
  ip_address = google_compute_global_address.lb-static-ip.self_link
  port_range = "80"
}

resource "google_compute_target_http_proxy" "mybalancer-target-proxy" {
  name    = "mybalancer-target-proxy"
  url_map = google_compute_url_map.mybalancer.self_link
}


resource "google_compute_url_map" "mybalancer" {
  #Load balancer - http balancer - получается это его название
  name            = "mybalancer"
  default_service = google_compute_backend_service.http-backend.self_link
}

resource "google_compute_backend_service" "http-backend" {
  name      = "http-backend"
  port_name = "http"
  protocol  = "HTTP"
  
  # Бекэнд - указываем группу экземпляров в которую балансируем
  backend {
    group = google_compute_instance_group.instance-group-1.self_link
  }

  health_checks = [
    "${google_compute_health_check.basic-check.self_link}",
  ]
}

resource "google_compute_health_check" "basic-check" {
  # Создаем health check, которым проверяем доступность машин
  name               = "basic-check"
  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = "9292"
  }
}
