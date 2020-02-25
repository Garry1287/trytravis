Test repo
[![Build Status](https://travis-ci.com/Garry1287/practice-git-1.svg?branch=master)](https://travis-ci.com/Garry1287/practice-git-1)


##Terraform 1
`terraform -v ` версия программы
`terraform init` скачивает указанных в файле tf модулей для работы с провайдерами (например гугл). Есть куча модулей, в том числе для ESXI и KVM
Terraform предоставляет широкий набор примитивов (resources) для управления ресурсами различных сервисов GCP.

main.tf - основной файл
```
resource "google_compute_instance" "app" {
  name = "reddit-app"
  machine_type = "g1-small"
  zone = "europe-west1-b"
# определение загрузочного диска
  boot_disk {
    initialize_params {
    image = "reddit-base"
  }
}
# определение сетевого интерфейса
network_interface {
  # сеть, к которой присоединить данный интерфейс
  network = "default"
  # использовать ephemeral IP для доступа из Интернет
  access_config {}
  }
}
```

`terraform plan` - покажет вносимые изменения в инфраструктуру
`terraform apply` - применение
Результат применения в файле terraform.tfstate

Набор для .gitignore
```
*.tfstate
*.tfstate.*.backup
*.tfstate.backup
*.tfvars
.terraform/
```

```
terraform show | grep nat_ip
network_interface.0.access_config.0.nat_ip = 35.205.174.46
```
Можно применить для поиска по возвращаемому

####Выходные переменные
outputs.tf - файл для получения возвращаемых значений от терраформ
```
output "app_external_ip" {
  #value = google_compute_instance.app.network_interface.0.access_config.0.assigned_nat_ip
  value = google_compute_instance.app[*].network_interface[*].access_config[0].nat_ip
}
```
Используем команду terraform refresh, чтобы выходная переменная приняла значение.

```
$ terraform output
app_external_ip = 104.155.68.69
$ terraform output app_external_ip
104.155.68.69
```

Provisioners в terraform вызываются в момент создания/
удаления ресурса и позволяют выполнять команды на удаленной
или локальной машине. Их используют для запуска инструментов
управления конфигурацией или начальной настройки системы.

Например можно с помощью ansible(он в данном случае provisioner) раскатать приложение
А есть простые
```
provisioner "file" {
source = "files/puma.service"
destination = "/tmp/puma.service"
}
```

###Input переменные
variables.tf - файл для определения переменных
Пример
```
provider "google" {
  # Версия провайдера
  version = "2.5.0"

  # ID проекта
  project = var.project
  region  = var.region
}
```
Теперь можно использовать input переменные

`terraform destroy` - удаляет все ресурсы


terraform.tfvars - файл для задания переменных.
В чём смысл использовать terraform.tfvars и variables.tf? Очень просто - в variables.tf описываем сами переменные и что они означают, а в terraform.tfvars присваиваем значения и этот файл в git не кладём. Для примеров можно класть в репо - terraform.tfvars.example.


`terraform fmt` форматирует правильно файлы


Опишите в коде терраформа добавление ssh ключей
нескольких пользователей в метаданные проекта (можно
просто один и тот же публичный ключ, но с разными именами
пользователей, например appuser1, appuser2 и т.д.).
Добавил
```
resource "google_compute_project_metadata" "default" {
  metadata {
    ssh-keys = "appuser1:${file(var.public_key_path)} appuser2:${file(var.public_key_path)} appuser3:${file(var.public_key_path)} appuser4:${file(var.public_key_path)} appuser5:${file(var.public_key_path)}"
  }
}
```


####Задание с балансировкой
Сначала справился с более легкой схемой - network balancing tcp

С network balancing tcp работало порт в порт и через target pools в Adviced (Load balancing)
            
            
            Это terraform для этой схемы
```          
resource "google_compute_forwarding_rule" "default" {
  name       = "reddit-app-lb-forwarding-rule"
  target     = "${google_compute_target_pool.default.self_link}"
  port_range = 9292
}

resource "google_compute_target_pool" "default" {
  name = "reddit-app-lb-target-pool"

  instances = [
    for item in google_compute_instance.app : item.self_link
  ]

  health_checks = [
    "${google_compute_http_health_check.reddit-app.name}",
  ]
}

resource "google_compute_http_health_check" "reddit-app" {
  name               = "reddit-app-http-health-check"
  port               = "9292"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}
```





Ветка terraform-1 - это решение задания с балансировщиками. Помучался, подсмотрел и у меня получилось
Сначала делал по документации руками из web интерфейса. Потом когда осознал, как и что, сделал на terraform

```
create 2 vm machine
    reddit-app-terraform0 	europe-west1-b 			10.132.0.31 (nic0) 	34.77.118.230
    reddit-app-terraform1 	europe-west1-b 			10.132.0.30 (nic0) 	35.195.68.153
create instance group with 2 vm 
    instance-group-1    	europe-west1-b 	2 	— 	Nov 29, 2019, 1:47:01 PM 			mybalancer 	
 
create static ipv4 
     lb-static-ip 	35.210.158.186 	europe-west1 	Static 	IPv4 	Forwarding rule http-frontend 	Standard 	


create LB  
             mybalancer 	HTTP 	europe-west1 	1 backend service (1 instance group, 0 network endpoint groups)
	

        backend
            http-backend 	Backend service 	Global 	HTTP 	mybalancer 
        frontend
            http-frontend 	Regional (europe-west1) 	35.210.158.186:80 	TCP 	Standard 	mybalancer 	
```

Грубая копия из веб-интерфейса
```
            forwarding rule
            
http-frontend		Regional 	europe-west1 	35.210.158.186:80  	tcp 	mybalancer-target-proxy
            target-proxy
 mybalancer-target-proxy    HTTP Proxy      mybalancer 

            backend
http-backend		Global 		mybalancer 
```
В следующий раз делать надо скрины.


Вот код для lb
```


resource "google_compute_instance_group" "instance-group-1" { 
    name  = "instance-group-1" 
    description = "Terraform test instance group" 

    instances = google_compute_instance.app[*].self_link 

    named_port {
      name = "http"
      port = "9292"
    }
    lifecycle {
      create_before_destroy = true
    }
  
   zone = "${var.region}"
} 

resource "google_compute_global_address" "lb-static-ip" {
  name = "lb-static-ip"
}

resource "google_compute_global_forwarding_rule" "http-frontend" {
  name       = "http-frontend"
  target     = "${google_compute_target_http_proxy.mybalancer-target-proxy.self_link}"
  port_range = "80"
}

resource "google_compute_target_http_proxy" "mybalancer-target-proxy " {
  name    = "mybalancer-target-proxy"
  url_map = "${google_compute_url_map.default.self_link}"
}


resource "google_compute_url_map" "default" {
  name            = "puma-urlmap"
  default_service = "${google_compute_backend_service.http-backend.self_link}"
}

resource "google_compute_backend_service" "http-backend" {
  name      = "http-backend"
  port_name = "http"
  protocol  = "HTTP"

  backend {
    group = "${google_compute_instance_group.instance-group-1.self_link}"
  }

  health_checks = [
    "${google_compute_health_check.default.self_link}",
  ]
}

resource "google_compute_health_check" "basic-check" {
  name               = "basic-check"
  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = "9292"
  }
}
```

    Добавлен файл lb.tf описывающий создание балансировщика для http
    В outputs добавлен вывод ip адреса балансировщика
    Добавлено создание еще одного инстанса, неудобство - копирование кода ведет к разрастанию файла и возможным ошибкам и неодинаковости инстансов
    Добавлено создание второго инстанса с приложением через count
    Добавлено автоматическое добавление инстансов в target_pool
    Добавлен вывод в outputs ip-адресов созданных инстансов







#Terraform-2




Команда import позволяет добавить информацию о созданном
без помощи Terraform ресурсе в state файл. В директории terraform
выполните команду:
`$ terraform import google_compute_firewall.firewall_ssh default-allow-ssh`
Это если мы руками добавили в веб-интерфейсе правило и теперь хотим, чтобы оно появилось в state

Можно ссылаться на атрибуты другого ресурса 
```
resource "google_compute_target_http_proxy" "mybalancer-target-proxy" {
  name    = "mybalancer-target-proxy"
  url_map = google_compute_url_map.mybalancer.self_link
}
```
Это формирует этапы создания и зависимости

Terraform поддерживает также явную зависимость используя
параметр depends_on .


Создаем 2 образа - для бд и основную машину в пакере
 reddit-app-base и reddit-db-base

Созданы новые файлы app.tf с описанием ресурсов для инстанса с приложением и db.tf с описанием ресурсов для инстанса с MongoDB

Создадим файл vpc.tf , в который вынесем правило фаервола
для ssh доступа, которое применимо для всех инстансов нашей
сети.


В итоге, в файле main.tf должно остаться только определение
провайдера



##Работа с модулями
На основе app.tf, db.tf создали следующее


-modules
 - app
      main.tf
      variables.tf
      outputs.tf
 - db
      main.tf
      variables.tf
      outputs.tf


В корне удалим db.tf, app.tf и сделаем main.tf
```
provider "google" {
  # Версия провайдера
  version = "2.5.0"

  # ID проекта
  project = var.project
  region  = var.region
}

module "app" {
  source          = "/modules/app"
  public_key_path = var.public_key_path
  zone            = var.zone
  app_disk_image  = var.app_disk_image
}

module "db" {
  source          = "/modules/db"
  public_key_path = var.public_key_path
  zone            = var.zone
  db_disk_image   = var.db_disk_image
}
```


Чтобы начать использовать модули, нам нужно сначала их
загрузить из указанного источника source . В нашем случае
источником модулей будет просто локальная папка на диске.
Используем команду для загрузки модулей. В директории terraform:
terraform get
Модули будут загружены в директорию .terraform, в которой уже
содержится провайдер 
```
$ terraform get
Get: file:///Users/user01/hw09/modules/app
Get: file:///Users/user01/hw09/modules/db
$ tree .terraform
.terraform
├── modules
│
├── 9926d1ca5a4ce00042725999e3b3a90f -> /Users/user01/hw09/modules/db
│
└── dea8bdea57c956cc3317d254e5822e13 -> /Users/user01/hw09/modules/app
└── plugins
└── darwin_amd64
├── lock.json
└── terraform-provider-google_v0.1.3_x4
```

Обнаружена проблема вывода outputs при запуске terraform plan
В outputs.tf изменен вывод app_external_ip на переменную, получаемую из модуля app value = "${module.app.app_external_ip}"
По аналогии с модулями app и db добавлен модуль vpc
Инфраструктура развернута и проверено подключение по ssh к хостам reddit-app и reddit-db

###Параметризация модулей

- В модуле vpc параметризирован параметр source_ranges для ресурса google_compute_firewall
- Проверена функциональность фильтра по адресу, если в source_ranges указан не мой IP - доступ по ssh к хостам отсутствует, если указан мой адрес или 0.0.0.0/0 - доступ по ssh есть


##Переиспользование модулей
Создаём две папки stage и prod (2 окружения)

Скопируйем файлы main.tf, variables.tf, outputs.tf, terraform.tfvars из директории terraform в каждую из
созданных директорий.

Поменяйте пути к модулям в main.tf на ../modules/xxx вместо
modules/xxx . Инфраструктура в обоих окружениях будет
идентична, однако будет иметь небольшие различия: мы откроем
SSH доступ для всех IP адресов в окружении Stage, а в окружении
Prod откроем доступ только для своего IP.

terraform/stage/main.tf
```
module "vpc" {
    source = "../modules/vpc"
    source_ranges = ["0.0.0.0/0"]
}
```


terraform/prod/main.tf
module "vpc" {
    source = "../modules/vpc"
    source_ranges = ["82.155.222.156/32"]
}

Удалены файл main.tf, outputs.tf, terraform.tfvars, variables.tf из директории terraform
Для модулей app и db параметризированы значения machine_type и ssh_user



## Работа с модулями
Давайте попробуем воспользоваться модулем storage-bucket
для создания бакета в сервисе Storage.


Создайте в папке terraform файл storage-bucket.tf с таким
содержанием:
```
provider "google" {
    version = "2.0.0"
    project = "${var.project}"
    region = "${var.region}"
}

module "bucket_stage" {
  source = "git::https://github.com/SweetOps/terraform-google-storage-bucket.git?ref=master"
# Имена поменяйте на другие
  name = ["storage-bucket-test", "storage-bucket-test2"]
}

output storage-bucket_url {
    value = "${module."bucket_stage.url}"
}
```


Это не сделал

. Настройте хранение стейт файла в удаленном бекенде (remote
backends) для окружений stage и prod, используя Google Cloud
Storage в качестве бекенда. Описание бекенда нужно вынести в
отдельный файл backend.tf
2. Перенесите конфигурационные файлы Terraform в другую
директорию (вне репозитория). Проверьте, что state-файл
( terraform.tfstate ) отсутствует. Запустите Terraform в обеих
директориях и проконтролируйте, что он "видит" текущее
состояние независимо от директории, в которой запускается
3. Попробуйте запустить применение конфигурации
одновременно, чтобы проверить работу блокировок
4. Добавьте описание в README.md

[https://www.terraform.io/docs/backends/types/gcs.html](https://www.terraform.io/docs/backends/types/gcs.html)
`cat storage-bucket.tf`
```
provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

module "storage-bucket" {
  source  = "SweetOps/storage-bucket/google"
  version = "0.3.0"
  location = var.region

  name = "storage-gis-tfstate"
}

output storage-bucket_url {
  value = module.storage-bucket.url
}
```
`cat terraform/prod/backend.tf`
```
terraform {
  required_version = "~> 0.12"
  backend "gcs" {
    bucket = "storage-gis-tfstate"
    prefix = "terraform/state-prod"
  }
}
```

-------------------------
В процессе перехода от конфигурации, созданной в
предыдущем ДЗ к модулям мы перестали использовать provisioner
для деплоя приложения. Соответственно, инстансы поднимаются
без приложения.
1. Добавьте необходимые provisioner в модули для деплоя и
работы приложения. Файлы, используемые в provisioner, должны
находится в директории модуля.
2. Опционально можете реализовать отключение provisioner в
зависимости от значения переменной
3. Добавьте описание в README.md
P.S. Приложение получает окружения DATABASE_URL .



Не работала связь app-db
`Can't show blog posts, some problems with database. Refresh?`

Проблема с пониманием разницы
```
output "db_addr" {
  value = module.db.internal_ip
}

output "db_addr" {
  value = ${module.db.internal_ip}
}

```
Но второй вариант не работал при apply
```
Error: 2 problems:

- Invalid template interpolation value: Cannot include the given value in a string template: string required.
- Invalid template interpolation value: Cannot include the given value in a string template: string required.
```


Получилось по ссылке парней.
[https://github.com/Otus-DevOps-2019-08/guildin_infra#tf2-%D0%B7%D0%B0%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%B6%D0%B6](https://github.com/Otus-DevOps-2019-08/guildin_infra#tf2-%D0%B7%D0%B0%D0%B4%D0%B0%D0%BD%D0%B8%D0%B5-%D0%B6%D0%B6)


В процессе выполнения предыдущих задач были выпечены (слава пакеру!) образы reddit-app-base и reddit-db-base. Это существенно ускорило работу terraform apply Однако ссылки на базы данных у сервера приложения нет, да и конфигурация самой базы данных - в умолчальном состоянии. Поэтому работа провижинеров призвана обеспечить необходимые изменения:

    Для начала, app-экземпляру необходимо узнать адрес db-экземпляра. Как мы помним, конфигуация файервола для db-экземляра разрешает трафик тегированных reddit-app ВМ (не нат!) на reddit-db ВМ.

```
resource "google_compute_firewall" "firewall_mongo" {
  name    = "allow-mongo-default"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  target_tags = ["reddit-db"] # - правило применяется к ВМ тегированным указанным тегом
  source_tags = ["reddit-app"] # - разрешается трафик с внутренних интерфейсов машин с указанным тегом. Логично.
}
```
Для этого положим его в output переменную ../modules/db/outputs.tf:
```
output "internal_ip" {
  value = google_compute_instance.db[*].network_interface[0].network_ip
}
```
...И сделаем ссылку в материнской конфигурации outputs.tf:
```
output "db_addr" {
  value = module.db.internal_ip
}
```
Наконец, упомянем его в конфигурации модуля app в материнской конфигурации:
```
module "app" {
...
  db_addr         = module.db.internal_ip
}
```
    Теперь нам необходимы провижинеры: Для app:
```
resource "null_resource" "post-install" {
  connection {
    type        = "ssh"
    host        = google_compute_address.app_ip.address
    user        = "appuser"
    agent       = false
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo echo DATABASE_URL=${var.db_addr.0} > /tmp/grab.env",                                   #  Вот он, вон он адрес СУБД, положим его куда попало
      "sudo sed -i '/Service/a EnvironmentFile=/tmp/grab.env' /etc/systemd/system/puma.service",   #  ...и сошлемся на это самое куда попало в юнит файле,
      "sudo systemctl daemon-reload",                                                              #  ...расскажем об этом systemd
      "sudo service puma restart",                                                                 #  перезагрузим сервис для применения новых настроек.
    ]
  }
```
Для db
```
... # опустим описание нуль-ресурса post-install
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf",   # Тут все проще. Заменим петлевой адрес на любой имеющийся (0.0.0.0) (Bind IP) 
      "sudo service mongod restart",                            # и рестартуем службу.
    ]
  }
```
    NB! В данном случае нам не понадобилось размещение в директориях модулей каких-либо файлов, но если такая необходимость возникнет, то путь к ним начинается c ${path.module}
    NB! Выведение провиженера в нуль-ресурс - очень важный архитектурный момент, если что-то в процессе идет не так, то taint и пересоздание происходит нуль-ресурса, а не экземпляра ВМ


--------------------------
Получается командой 
```
module "app" {
  source          = "/modules/app"
  public_key_path = var.public_key_path
  zone            = var.zone
  app_disk_image  = var.app_disk_image
}
```
мы используем часть написанного инфраструктурного кода для поднятия app сервера и приложений несколько раз. Разница в stage и prod заключаются в переменных zone, app_disk_image которые мы передаём в модуль. Также например через count можно запускать разное количество машин, разные типы. В этом плюс модульной системы.

-------------------------





#Ansible

(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible dbserver -i ./inventory -m ping
The authenticity of host '104.199.19.235 (104.199.19.235)' can't be established.
ECDSA key fingerprint is SHA256:tcnMhNXajKGfEAHiqTs1C6I93Ggdl8P5sGd+tL3xs3Y.
Are you sure you want to continue connecting (yes/no)? yes
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
dbserver | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ vi ansible.cfg
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible dbserver -m command -a uptime
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
dbserver | CHANGED | rc=0 >>
 11:40:28 up 12 min,  1 user,  load average: 0.03, 0.10, 0.11
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ vi inventory 
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible dbserver -m command -a uptime
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
dbserver | CHANGED | rc=0 >>
 11:41:49 up 13 min,  1 user,  load average: 0.00, 0.07, 0.10
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible app -m ping
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
appserver | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ls
ansible.cfg  inventory
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ vi inventory.yml
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible all -m ping -i inventory.yml
appserver | UNREACHABLE! => {
    "changed": false, 
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 35.190.196.109 port 22: Connection timed out", 
    "unreachable": true
}
dbserver | UNREACHABLE! => {
    "changed": false, 
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 104.155.9.218 port 22: Connection timed out", 
    "unreachable": true
}
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ cat inventory.yml
app:
  hosts:
    appserver:
      ansible_host: 35.190.196.109

db:
  hosts:
    dbserver:
      ansible_host: 104.155.9.218
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ cat inventory
[app]
appserver ansible_host=35.233.73.20 
[db]
dbserver ansible_host=104.199.19.235
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ vi inventory.yml
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible all -m ping -i inventory.yml
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
dbserver | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
appserver | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"


(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible app -m command -a 'ruby -v'
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
appserver | CHANGED | rc=0 >>
ruby 2.3.1p112 (2016-04-26) [x86_64-linux-gnu]




Проверим на хосте с БД статус сервиса MongoDB с помощью
модуля command или shell . (Эта операция аналогична запуску на
хосте команды systemctl status mongod ):
$ ansible db -m command -a 'systemctl status mongod'
dbserver | SUCCESS | rc=0 >>
● mongod.service - High-performance, schema-free document-oriented database
$ ansible db -m shell -a 'systemctl status mongod'
dbserver | SUCCESS | rc=0 >>
● mongod.service - High-performance, schema-free document-oriented database
А можем выполнить ту же операцию используя модуль
systemd , который предназначен для управления сервисами:



(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible db -m command -a 'systemctl status mongod'
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
dbserver | CHANGED | rc=0 >>
● mongod.service - High-performance, schema-free document-oriented database
   Loaded: loaded (/lib/systemd/system/mongod.service; enabled; vendor preset: enabled)
   Active: active (running) since Tue 2020-02-18 11:28:36 UTC; 18min ago
     Docs: https://docs.mongodb.org/manual
 Main PID: 1940 (mongod)
    Tasks: 21
   Memory: 31.4M
      CPU: 5.425s
   CGroup: /system.slice/mongod.service
           └─1940 /usr/bin/mongod --quiet --config /etc/mongod.conf

Feb 18 11:28:36 reddit-db systemd[1]: Stopped High-performance, schema-free document-oriented database.
Feb 18 11:28:36 reddit-db systemd[1]: Started High-performance, schema-free document-oriented database.
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible db -m systemd -a name=mongod
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
dbserver | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "name": "mongod", 
    "status": {
        "ActiveEnterTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "ActiveEnterTimestampMonotonic": "21244747", 
        "ActiveExitTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "ActiveExitTimestampMonotonic": "21145901", 
        "ActiveState": "active", 
        "After": "network.target systemd-journald.socket basic.target system.slice sysinit.target", 
        "AllowIsolate": "no", 
        "AmbientCapabilities": "0", 
        "AssertResult": "yes", 
        "AssertTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "AssertTimestampMonotonic": "21243903", 
        "Before": "multi-user.target shutdown.target", 
        "BlockIOAccounting": "no", 
        "BlockIOWeight": "18446744073709551615", 
        "CPUAccounting": "no", 
        "CPUQuotaPerSecUSec": "infinity", 
        "CPUSchedulingPolicy": "0", 
        "CPUSchedulingPriority": "0", 
        "CPUSchedulingResetOnFork": "no", 
        "CPUShares": "18446744073709551615", 
        "CPUUsageNSec": "5558701604", 
        "CanIsolate": "no", 
        "CanReload": "no", 
        "CanStart": "yes", 
        "CanStop": "yes", 
        "CapabilityBoundingSet": "18446744073709551615", 
        "ConditionResult": "yes", 
        "ConditionTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "ConditionTimestampMonotonic": "21243902", 
        "Conflicts": "shutdown.target", 
        "ControlGroup": "/system.slice/mongod.service", 
        "ControlPID": "0", 
        "DefaultDependencies": "yes", 
        "Delegate": "no", 
        "Description": "High-performance, schema-free document-oriented database", 
        "DevicePolicy": "auto", 
        "Documentation": "https://docs.mongodb.org/manual", 
        "ExecMainCode": "0", 
        "ExecMainExitTimestampMonotonic": "0", 
        "ExecMainPID": "1940", 
        "ExecMainStartTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "ExecMainStartTimestampMonotonic": "21244713", 
        "ExecMainStatus": "0", 
        "ExecStart": "{ path=/usr/bin/mongod ; argv[]=/usr/bin/mongod --quiet --config /etc/mongod.conf ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", 
        "FailureAction": "none", 
        "FileDescriptorStoreMax": "0", 
        "FragmentPath": "/lib/systemd/system/mongod.service", 
        "Group": "mongodb", 
        "GuessMainPID": "yes", 
        "IOScheduling": "0", 
        "Id": "mongod.service", 
        "IgnoreOnIsolate": "no", 
        "IgnoreSIGPIPE": "yes", 
        "InactiveEnterTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "InactiveEnterTimestampMonotonic": "21243059", 
        "InactiveExitTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "InactiveExitTimestampMonotonic": "21244747", 
        "JobTimeoutAction": "none", 
        "JobTimeoutUSec": "infinity", 
        "KillMode": "control-group", 
        "KillSignal": "15", 
        "LimitAS": "18446744073709551615", 
        "LimitASSoft": "18446744073709551615", 
        "LimitCORE": "18446744073709551615", 
        "LimitCORESoft": "0", 
        "LimitCPU": "18446744073709551615", 
        "LimitCPUSoft": "18446744073709551615", 
        "LimitDATA": "18446744073709551615", 
        "LimitDATASoft": "18446744073709551615", 
        "LimitFSIZE": "18446744073709551615", 
        "LimitFSIZESoft": "18446744073709551615", 
        "LimitLOCKS": "18446744073709551615", 
        "LimitLOCKSSoft": "18446744073709551615", 
        "LimitMEMLOCK": "18446744073709551615", 
        "LimitMEMLOCKSoft": "18446744073709551615", 
        "LimitMSGQUEUE": "819200", 
        "LimitMSGQUEUESoft": "819200", 
        "LimitNICE": "0", 
        "LimitNICESoft": "0", 
        "LimitNOFILE": "64000", 
        "LimitNOFILESoft": "64000", 
        "LimitNPROC": "64000", 
        "LimitNPROCSoft": "64000", 
        "LimitRSS": "18446744073709551615", 
        "LimitRSSSoft": "18446744073709551615", 
        "LimitRTPRIO": "0", 
        "LimitRTPRIOSoft": "0", 
        "LimitRTTIME": "18446744073709551615", 
        "LimitRTTIMESoft": "18446744073709551615", 
        "LimitSIGPENDING": "6670", 
        "LimitSIGPENDINGSoft": "6670", 
        "LimitSTACK": "18446744073709551615", 
        "LimitSTACKSoft": "8388608", 
        "LoadState": "loaded", 
        "MainPID": "1940", 
        "MemoryAccounting": "no", 
        "MemoryCurrent": "32976896", 
        "MemoryLimit": "18446744073709551615", 
        "MountFlags": "0", 
        "NFileDescriptorStore": "0", 
        "Names": "mongod.service", 
        "NeedDaemonReload": "no", 
        "Nice": "0", 
        "NoNewPrivileges": "no", 
        "NonBlocking": "no", 
        "NotifyAccess": "none", 
        "OOMScoreAdjust": "0", 
        "OnFailureJobMode": "replace", 
        "PermissionsStartOnly": "no", 
        "PrivateDevices": "no", 
        "PrivateNetwork": "no", 
        "PrivateTmp": "no", 
        "ProtectHome": "no", 
        "ProtectSystem": "no", 
        "RefuseManualStart": "no", 
        "RefuseManualStop": "no", 
        "RemainAfterExit": "no", 
        "Requires": "system.slice sysinit.target", 
        "Restart": "no", 
        "RestartUSec": "100ms", 
        "Result": "success", 
        "RootDirectoryStartOnly": "no", 
        "RuntimeDirectoryMode": "0755", 
        "RuntimeMaxUSec": "infinity", 
        "SameProcessGroup": "no", 
        "SecureBits": "0", 
        "SendSIGHUP": "no", 
        "SendSIGKILL": "yes", 
        "Slice": "system.slice", 
        "StandardError": "inherit", 
        "StandardInput": "null", 
        "StandardOutput": "journal", 
        "StartLimitAction": "none", 
        "StartLimitBurst": "5", 
        "StartLimitInterval": "10000000", 
        "StartupBlockIOWeight": "18446744073709551615", 
        "StartupCPUShares": "18446744073709551615", 
        "StateChangeTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "StateChangeTimestampMonotonic": "21244747", 
        "StatusErrno": "0", 
        "StopWhenUnneeded": "no", 
        "SubState": "running", 
        "SyslogFacility": "3", 
        "SyslogLevel": "6", 
        "SyslogLevelPrefix": "yes", 
        "SyslogPriority": "30", 
        "SystemCallErrorNumber": "0", 
        "TTYReset": "no", 
        "TTYVHangup": "no", 
        "TTYVTDisallocate": "no", 
        "TasksAccounting": "no", 
        "TasksCurrent": "21", 
        "TasksMax": "18446744073709551615", 
        "TimeoutStartUSec": "1min 30s", 
        "TimeoutStopUSec": "1min 30s", 
        "TimerSlackNSec": "50000", 
        "Transient": "no", 
        "Type": "simple", 
        "UMask": "0022", 
        "UnitFilePreset": "enabled", 
        "UnitFileState": "enabled", 
        "User": "mongodb", 
        "UtmpMode": "init", 
        "WantedBy": "multi-user.target", 
        "WatchdogTimestamp": "Tue 2020-02-18 11:28:36 UTC", 
        "WatchdogTimestampMonotonic": "21244746", 
        "WatchdogUSec": "0"
    }
}



Playbook
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible app -m git -a 'repo=https://github.com/express42/reddit.git dest=/home/appuser/reddit'
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
appserver | SUCCESS => {
    "after": "5c217c565c1122c5343dc0514c116ae816c17ca2", 
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "before": "5c217c565c1122c5343dc0514c116ae816c17ca2", 
    "changed": false, 
    "remote_url_changed": false
}
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ vi clone.yml
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible-playbook clone.yml

PLAY [Clone] *********************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************************************************************
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
ok: [appserver]

TASK [Clone repo] ****************************************************************************************************************************************************************************************************************************
ok: [appserver]

PLAY RECAP ***********************************************************************************************************************************************************************************************************************************
appserver                  : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible app -m command -a 'rm -rf
> ~/reddit'
[WARNING]: Consider using the file module with state=absent rather than running 'rm'.  If you need to use command because file is insufficient you can add 'warn: false' to this command task or set 'command_warnings=False' in ansible.cfg
to get rid of this message.
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
appserver | CHANGED | rc=0 >>

(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible-playbook clone.yml

PLAY [Clone] *********************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************************************************************
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host appserver should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
ok: [appserver]

TASK [Clone repo] ****************************************************************************************************************************************************************************************************************************
changed: [appserver]

PLAY RECAP ***********************************************************************************************************************************************************************************************************************************
appserver                  : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   



------------------------
Чтобы работать с динамически изменяемыми ip адресам gcp или aws
можно в качестве инвентори использовать либо скриптом самописным распарсенный tfstate файл из которого достаём в json формате группы и ip
[https://medium.com/@Nklya/%D0%B4%D0%B8%D0%BD%D0%B0%D0%BC%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5-%D0%B8%D0%BD%D0%B2%D0%B5%D0%BD%D1%82%D0%BE%D1%80%D0%B8-%D0%B2-ansible-9ee880d540d6](https://medium.com/@Nklya/%D0%B4%D0%B8%D0%BD%D0%B0%D0%BC%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5-%D0%B8%D0%BD%D0%B2%D0%B5%D0%BD%D1%82%D0%BE%D1%80%D0%B8-%D0%B2-ansible-9ee880d540d6)


Или воспользовтаь плагином, предварительно получив service_account_file из веб-интерфейс GCP
[https://medium.com/@Temikus/ansible-gcp-dynamic-inventory-2-0-7f3531b28434](https://medium.com/@Temikus/ansible-gcp-dynamic-inventory-2-0-7f3531b28434)

`cat inventory.gcp.yml`
```
plugin: gcp_compute
projects:
  - myprojtest-254911
zones:
  - "europe-west1-b"
filters: []
auth_kind: serviceaccount
service_account_file: "/home/garry/.ssh/myprojtest-254911-9b1bd3cb44d6.json"
```


Результат
```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible -i inventory.gcp.yml all -m ping
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host 104.199.19.235 should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
104.199.19.235 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host 35.233.73.20 should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
35.233.73.20 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
10.132.0.13 | UNREACHABLE! => {
    "changed": false, 
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 10.132.0.13 port 22: Connection timed out", 
    "unreachable": true
}
```



###Ansible-2

```
terraform destroy
terraform apply -auto-approve=false
```

Всё делал по слайду, всё ясно и понятно

Задание с gce.py

* скачал gce.py и gce.ini c ansible repo из интернета
```
rm -rf gce.ini
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ wget https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/gce.ini
--2020-02-19 16:19:50--  https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/gce.ini
Распознаётся raw.githubusercontent.com (raw.githubusercontent.com)… 151.101.36.133
Подключение к raw.githubusercontent.com (raw.githubusercontent.com)|151.101.36.133|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа… 200 OK
Длина: 3452 (3,4K) [text/plain]
Сохранение в: «gce.ini»

gce.ini                                                     100%[=========================================================================================================================================>]   3,37K  --.-KB/s    за 0s      

2020-02-19 16:19:51 (31,2 MB/s) - «gce.ini» сохранён [3452/3452]

(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ wget https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/gce.py
--2020-02-19 16:19:58--  https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/gce.py
Распознаётся raw.githubusercontent.com (raw.githubusercontent.com)… 151.101.36.133
Подключение к raw.githubusercontent.com (raw.githubusercontent.com)|151.101.36.133|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа… 200 OK
Длина: 19275 (19K) [text/plain]
Сохранение в: «gce.py»

gce.py                                                      100%[=========================================================================================================================================>]  18,82K  --.-KB/s    за 0,05s   

2020-02-19 16:19:58 (373 KB/s) - «gce.py» сохранён [19275/19275]

```

* Прописал в gce.ini
```
gce_service_account_email_address = 900793983812-compute@developer.gserviceaccount.com #Данные из предыдущей задачи
gce_service_account_pem_file_path = /home/garry/.ssh/myprojtest-254911-9b1bd3cb44d6.json #И файлик оттуда
gce_project_id = myprojtest-254911
gce_zone = europe-west1-b
```

* `export GCE_INI_PATH=/home/garry/devops_otus/garry_infra/ansible/gce.ini` переменную добавил
* Запустил скрипт 
```
./gce.py --list
{"reddit-app-base-1575888058": ["reddit-app"], "tag_reddit-db": ["reddit-db"], "europe-west1-b": ["reddit-app", "reddit-db", "reddit2-app"], "null": ["reddit2-app"], "tag_reddit-app": ["reddit-app"], "35.195.138.47": ["reddit-db"], "reddit-db-base-1575888276": ["reddit-db"], "10.132.0.2": ["reddit-db"], "status_running": ["reddit-app", "reddit-db"], "34.77.136.235": ["reddit-app"], "g1-small": ["reddit-app", "reddit-db", "reddit2-app"], "_meta": {"stats": {"cache_used": false, "inventory_load_time": 0.7060279846191406}, "hostvars": {"reddit-app": {"gce_uuid": "3b14d775d87f986bd1e2856810ad165beec7423b", "gce_public_ip": "34.77.136.235", "ansible_ssh_host": "34.77.136.235", "gce_private_ip": "10.132.15.232", "gce_id": "350209496584329643", "gce_image": "reddit-app-base-1575888058", "gce_description": null, "gce_machine_type": "g1-small", "gce_subnetwork": "default", "gce_tags": ["reddit-app"], "gce_name": "reddit-app", "gce_zone": "europe-west1-b", "gce_status": "RUNNING", "gce_network": "default", "gce_metadata": {"ssh-keys": "appuser:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwbN5qYWOJEXpQEqHYmT3FTtp92xgxAjlT15CsjcaLkQEKKDoEXiLS8zRoyBMTKC49WBqgaVnn8ZU1lwzMK4KooikxmNcziXlyniNCFbqbqIMirs2K6uTQhFdJsoO32AjFuLeQtJvvL3ZyIpi3VN+V/bnGV4ni3hFuQB3d6PuY8xoSD97MBjKjzKB7OeI5TB/tKEDEVqpM6D1EcEliI8HMr7AhnGsL+praHUZ7X8yf5VlZhO3+0QvinBKvHxgZuo1y120E9DwWAxZobFsuNEoIz10Y0xHKAkpgTpvwJjNB9xXFlA/8vWi7JCkBqmtV2R95tSTm3LfmQwTTbidxFwBd appuser\n"}}, "reddit-db": {"gce_uuid": "ac21a7dcf68e835ad35380de3688939f68e8e3ad", "gce_public_ip": "35.195.138.47", "ansible_ssh_host": "35.195.138.47", "gce_private_ip": "10.132.0.2", "gce_id": "1624279848084085166", "gce_image": "reddit-db-base-1575888276", "gce_description": null, "gce_machine_type": "g1-small", "gce_subnetwork": "default", "gce_tags": ["reddit-db"], "gce_name": "reddit-db", "gce_zone": "europe-west1-b", "gce_status": "RUNNING", "gce_network": "default", "gce_metadata": {"ssh-keys": "appuser:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwbN5qYWOJEXpQEqHYmT3FTtp92xgxAjlT15CsjcaLkQEKKDoEXiLS8zRoyBMTKC49WBqgaVnn8ZU1lwzMK4KooikxmNcziXlyniNCFbqbqIMirs2K6uTQhFdJsoO32AjFuLeQtJvvL3ZyIpi3VN+V/bnGV4ni3hFuQB3d6PuY8xoSD97MBjKjzKB7OeI5TB/tKEDEVqpM6D1EcEliI8HMr7AhnGsL+praHUZ7X8yf5VlZhO3+0QvinBKvHxgZuo1y120E9DwWAxZobFsuNEoIz10Y0xHKAkpgTpvwJjNB9xXFlA/8vWi7JCkBqmtV2R95tSTm3LfmQwTTbidxFwBd appuser\n"}}, "reddit2-app": {"gce_uuid": "05d22597558246b65b6443508d1ae966312cd8fa", "gce_public_ip": null, "ansible_ssh_host": null, "gce_private_ip": "10.132.0.13", "gce_id": "1941922074421470792", "gce_image": "reddit-full-1571138078", "gce_description": null, "gce_machine_type": "g1-small", "gce_subnetwork": "default", "gce_tags": ["puma-server"], "gce_name": "reddit2-app", "gce_zone": "europe-west1-b", "gce_status": "TERMINATED", "gce_network": "default", "gce_metadata": {}}}}, "10.132.0.13": ["reddit2-app"], "reddit-full-1571138078": ["reddit2-app"], "10.132.15.232": ["reddit-app"], "status_terminated": ["reddit2-app"], "network_default": ["reddit-app", "reddit-db", "reddit2-app"], "tag_puma-server": ["reddit2-app"]}

```
Это и есть динамический env, прописал inventory = ./gce.py в ansbile.cfg
[https://medium.com/vimeo-engineering-blog/orchestrating-gce-instances-with-ansible-d825a33793cd](https://medium.com/vimeo-engineering-blog/orchestrating-gce-instances-with-ansible-d825a33793cd)

[https://docs.ansible.com/ansible/2.5/scenario_guides/guide_gce.html](https://docs.ansible.com/ansible/2.5/scenario_guides/guide_gce.html) 

`ansible-playbook site.yml`
```
ansible-playbook site.yml
[DEPRECATION WARNING]: The TRANSFORM_INVALID_GROUP_CHARS settings is set to allow bad characters in group names by default, this will change, but still be user configurable on deprecation. This feature will be removed in version 2.10. 
Deprecation warnings can be disabled by setting deprecation_warnings=False in ansible.cfg.
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details

PLAY [Configure MongoDB] *********************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************************************************************
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host reddit-db should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
ok: [reddit-db]

TASK [Change mongo config file] **************************************************************************************************************************************************************************************************************
changed: [reddit-db]

RUNNING HANDLER [restart mongod] *************************************************************************************************************************************************************************************************************
changed: [reddit-db]

PLAY [Configure App] *************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************************************************************
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host reddit-app should use /usr/bin/python3, but is using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible release will default to using the 
discovered platform python for this host. See https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information. This feature will be removed in version 2.12. Deprecation warnings can be disabled 
by setting deprecation_warnings=False in ansible.cfg.
ok: [reddit-app]

TASK [Add unit file for Puma] ****************************************************************************************************************************************************************************************************************
changed: [reddit-app]

TASK [Add config for DB connection] **********************************************************************************************************************************************************************************************************
changed: [reddit-app]

TASK [enable puma] ***************************************************************************************************************************************************************************************************************************
changed: [reddit-app]

RUNNING HANDLER [reload puma] ****************************************************************************************************************************************************************************************************************
changed: [reddit-app]

PLAY [Deploy App] ****************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************************************************************
ok: [reddit-app]

TASK [Fetch the latest version of application code] ******************************************************************************************************************************************************************************************
changed: [reddit-app]

TASK [bundle install] ************************************************************************************************************************************************************************************************************************
changed: [reddit-app]

RUNNING HANDLER [restart puma] ***************************************************************************************************************************************************************************************************************
changed: [reddit-app]

PLAY RECAP ***********************************************************************************************************************************************************************************************************************************
reddit-app                 : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
reddit-db                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

```

###Packer and ansible
*Добавил ansible provisioners в packer
*Проверил образы
``` 
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$  packer validate -var-file=packer/variables.json packer/app.json
Template validated successfully.
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$  packer validate -var-file=packer/variables.json packer/db.json
Template validated successfully.
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$ 

```

SSH правило по умолчанию у меня не было в GCP
```
default-allow-ssh
	
Ingress
	
Apply to all
	
IP ranges: 0.0.0.0/0
	
tcp:22
	
Allow
	
1000
	
default 
```
И надо было добавить в metadata ssh-ключ appuser

И тогда успех
```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$  packer build -var-file=packer/variables.json packer/app.json
googlecompute output will be in this color.

==> googlecompute: Checking image does not exist...
==> googlecompute: Creating temporary SSH key for instance...
==> googlecompute: Using image: ubuntu-1604-xenial-v20200129
==> googlecompute: Creating instance...
    googlecompute: Loading zone: europe-west1-b
    googlecompute: Loading machine type: f1-micro
    googlecompute: Requesting instance creation...
    googlecompute: Waiting for creation operation to complete...
    googlecompute: Instance has been created!
==> googlecompute: Waiting for the instance to become running...
    googlecompute: IP: 34.76.67.8
==> googlecompute: Using ssh communicator to connect: 34.76.67.8
==> googlecompute: Waiting for SSH to become available...
==> googlecompute: Connected to SSH!
==> googlecompute: Provisioning with Ansible...
==> googlecompute: Executing Ansible: ansible-playbook --extra-vars packer_build_name=googlecompute packer_builder_type=googlecompute -o IdentitiesOnly=yes -i /tmp/packer-provisioner-ansible211714552 /home/garry/devops_otus/garry_infra/ansible/packer_app.yml -e ansible_ssh_private_key_file=/tmp/ansible-key365418941
    googlecompute:
    googlecompute: PLAY [Install Ruby && Bundler] *************************************************
    googlecompute:
    googlecompute: TASK [Gathering Facts] *********************************************************
    googlecompute: [DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host default should use
    googlecompute: ok: [default]
    googlecompute: /usr/bin/python3, but is using /usr/bin/python for backward compatibility with
    googlecompute: prior Ansible releases. A future Ansible release will default to using the
    googlecompute: discovered platform python for this host. See https://docs.ansible.com/ansible/
    googlecompute: 2.9/reference_appendices/interpreter_discovery.html for more information. This
    googlecompute: feature will be removed in version 2.12. Deprecation warnings can be disabled
    googlecompute: by setting deprecation_warnings=False in ansible.cfg.
    googlecompute:
    googlecompute: TASK [Install ruby and rubygems and required packages] *************************
    googlecompute: [DEPRECATION WARNING]: Invoking "apt" only once while using a loop via
    googlecompute: squash_actions is deprecated. Instead of using a loop to supply multiple items
    googlecompute: and specifying `name: "{{ item }}"`, please use `name: ['ruby-full', 'ruby-
    googlecompute: bundler', 'build-essential']` and remove the loop. This feature will be removed
    googlecompute:  in version 2.11. Deprecation warnings can be disabled by setting
    googlecompute: deprecation_warnings=False in ansible.cfg.
    googlecompute: changed: [default] => (item=[u'ruby-full', u'ruby-bundler', u'build-essential'])
    googlecompute: [WARNING]: Updating cache and auto-installing missing dependency: python-apt
    googlecompute:
    googlecompute: PLAY RECAP *********************************************************************
    googlecompute: default                    : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
    googlecompute:
==> googlecompute: Deleting instance...
    googlecompute: Instance has been deleted!
==> googlecompute: Creating image...
==> googlecompute: Deleting disk...
    googlecompute: Disk has been deleted!
Build 'googlecompute' finished.

==> Builds finished. The artifacts of successful builds are:
--> googlecompute: A disk image was created: reddit-app-base-1582185131
```




Второй образ не собирался
```
    googlecompute: fatal: [default]: FAILED! => {"cache_update_time": 1582185455, "cache_updated": false, "changed": false, "msg": "'/usr/bin/apt-get -y -o \"Dpkg::Options::=--force-confdef\" -o \"Dpkg::Options::=--force-confold\"      install 'mongodb-org'' failed: E: There were unauthenticated packages and -y was used without --allow-unauthenticated\n", "rc": 100, "stderr": "E: There were unauthenticated packages and -y was used without --allow-unauthenticated\n", "stderr_lines": ["E: There were unauthenticated packages and -y was used without --allow-unauthenticated"], "stdout": "Reading package lists...\nBuilding dependency tree...\nReading state information...\nThe following package was automatically installed and is no longer required:\n  grub-pc-bin\nUse 'sudo apt autoremove' to remove it.\nThe following additional packages will be installed:\n  mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools\nThe following NEW packages will be installed:\n  mongodb-org mongodb-org-mongos mongodb-org-server mongodb-org-shell\n  mongodb-org-tools\n0 upgraded, 5 newly installed, 0 to remove and 21 not upgraded.\nNeed to get 51.8 MB of archives.\nAfter this operation, 215 MB of additional disk space will be used.\nWARNING: The following packages cannot be authenticated!\n  mongodb-org-shell mongodb-org-server mongodb-org-mongos mongodb-org-tools\n  mongodb-org\n", "stdout_lines": ["Reading package lists...", "Building dependency tree...", "Reading state information...", "The following package was automatically installed and is no longer required:", "  grub-pc-bin", "Use 'sudo apt autoremove' to remove it.", "The following additional packages will be installed:", "  mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools", "The following NEW packages will be installed:", "  mongodb-org mongodb-org-mongos mongodb-org-server mongodb-org-shell", "  mongodb-org-tools", "0 upgraded, 5 newly installed, 0 to remove and 21 not upgraded.", "Need to get 51.8 MB of archives.", "After this operation, 215 MB of additional disk space will be used.", "WARNING: The following packages cannot be authenticated!", "  mongodb-org-shell mongodb-org-server mongodb-org-mongos mongodb-org-tools", "  mongodb-org"]}
```
Пока не добавил строку в ansible-playbook
`allow_unauthenticated: yes`


Собрался
```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$  packer build -var-file=packer/variables.json packer/db.json
googlecompute output will be in this color.

==> googlecompute: Checking image does not exist...
==> googlecompute: Creating temporary SSH key for instance...
==> googlecompute: Using image: ubuntu-1604-xenial-v20200129
==> googlecompute: Creating instance...
    googlecompute: Loading zone: europe-west1-b
    googlecompute: Loading machine type: f1-micro
    googlecompute: Requesting instance creation...
    googlecompute: Waiting for creation operation to complete...
    googlecompute: Instance has been created!
==> googlecompute: Waiting for the instance to become running...
    googlecompute: IP: 34.76.67.8
==> googlecompute: Using ssh communicator to connect: 34.76.67.8
==> googlecompute: Waiting for SSH to become available...
==> googlecompute: Connected to SSH!
==> googlecompute: Provisioning with Ansible...
==> googlecompute: Executing Ansible: ansible-playbook --extra-vars packer_build_name=googlecompute packer_builder_type=googlecompute -o IdentitiesOnly=yes -i /tmp/packer-provisioner-ansible035314273 /home/garry/devops_otus/garry_infra/ansible/packer_db.yml -e ansible_ssh_private_key_file=/tmp/ansible-key186724490
    googlecompute:
    googlecompute: PLAY [Install MongoDB 3.2] *****************************************************
    googlecompute:
    googlecompute: TASK [Gathering Facts] *********************************************************
    googlecompute: [DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host default should use
    googlecompute: ok: [default]
    googlecompute: /usr/bin/python3, but is using /usr/bin/python for backward compatibility with
    googlecompute: prior Ansible releases. A future Ansible release will default to using the
    googlecompute: discovered platform python for this host. See https://docs.ansible.com/ansible/
    googlecompute: 2.9/reference_appendices/interpreter_discovery.html for more information. This
    googlecompute: feature will be removed in version 2.12. Deprecation warnings can be disabled
    googlecompute: by setting deprecation_warnings=False in ansible.cfg.
    googlecompute:
    googlecompute: TASK [Add APT key] *************************************************************
    googlecompute: changed: [default]
    googlecompute:
    googlecompute: TASK [Add APT repository] ******************************************************
    googlecompute: changed: [default]
    googlecompute:
    googlecompute: TASK [Install mongodb package] *************************************************
    googlecompute: changed: [default]
    googlecompute:
    googlecompute: TASK [Configure service supervisor] ********************************************
    googlecompute: changed: [default]
    googlecompute:
    googlecompute: PLAY RECAP *********************************************************************
    googlecompute: default                    : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
    googlecompute:
==> googlecompute: Deleting instance...
    googlecompute: Instance has been deleted!
==> googlecompute: Creating image...
==> googlecompute: Deleting disk...
    googlecompute: Disk has been deleted!
Build 'googlecompute' finished.

==> Builds finished. The artifacts of successful builds are:
--> googlecompute: A disk image was created: reddit-db-base-1582186492
```

Все запустилось, проблема только в переменной 
```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ cat app.yml
---
- name: Configure App
  hosts: tag_reddit-app
  become: true
  vars:
    db_host: 10.132.0.18
  tasks:
    - name: Add unit file for Puma
      copy:
      ...
```

Надо db_host брать из invetory тоже.



#Ansible-3
Создаем роли
```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ cd roles/
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible/roles$ ansible-galaxy init app
- Role app was created successfully
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible/roles$ ansible-galaxy init db
```

Перекинули файлы, обновили app.yml и db.yml - получилось

###Работа с 2 окружениями
Перекинули inventory в prod и stage

Например, чтобы задеплоить приложение на prod окружении мы
должны теперь написать:
$ ansible-playbook -i environments/prod/inventory deploy.yml


```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra/ansible$ ansible-playbook -i environments/stage/inventory playbooks/site.yml
```

Засада с inventory, так как использовал gce.py, пришлось руками поменять hosts:tagg_reddit-db на db и с app та жа фигня.

db_host переменная не сработала, потому что я её не удалил из app.yml
```
#  vars:
#    db_host: 10.132.0.22
```




Конечно, чтобы шифровать и расшифровывать файлы нужен будет достаточно длинный ключ и хранить его нужно в надежном месте (например KeePass). Чтобы автоматически расшифровывать файлы во время запуска (runtime) плейбуков нужно будет указывать ключ --vault-password-file либо задавать путь к файлу через конфиг ansible.cfg, в этом случае также нужно будет позаботиться о сохранности ключа и выставить ему нужные права (0400). Ну и конечно не стоит его хранить в репозитории вместе с зашифрованными файлами.


https://rtfm.co.ua/ansible-ispolzovanie-vault-zashifrovannogo-xranilishha/
https://itsecforu.ru/2019/08/26/%F0%9F%92%BD-%D1%88%D0%BF%D0%B0%D1%80%D0%B3%D0%B0%D0%BB%D0%BA%D0%B0-ansible-vault-%D1%81%D0%BF%D1%80%D0%B0%D0%B2%D0%BE%D1%87%D0%BD%D0%BE%D0%B5-%D1%80%D1%83%D0%BA%D0%BE%D0%B2%D0%BE%D0%B4%D1%81%D1%82/
https://habr.com/ru/post/304732/
https://otus.ru/nest/post/232/



###Работа с Ansible Vault

* Создан файл vault.key с паролем для Ansible Vault
* В ansible.cfg добавлен параметр vault_password_file
* Добавлен плейбук для создания пользователей - users.yml
* Добавлены credentials.yml для окружений
* Файлы credentials.yml зашифрованы
* Вызов плейбука users.yml добавлен в site.yml и применен для stage-окружения

###HW12: Задание со * - Работа с динамическим инветори

* Добавил gce.py в директорию для каждого окружения
* Добавить в group_vars файлы tag_reddit-app и tag_reddit-db со значениями переменных для ролей.
* Запустил ansible-playbook -i environments/stage/gce.py playbooks/site.yml на чистой инфраструктуре, получился работоспособное приложение

Пользователи из vault добавились
```
appuser:x:1001:1002::/home/appuser:/bin/bash
admin:x:1002:100::/home/admin:
qauser:x:1003:1003::/home/qauser:
appuser@reddit-app:~$ 
```

Trytravis
```
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$ git remote remove trytravise
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$ git remote add trytravis https://github.com/Garry1287/trytravis.git
(env-ansible) garry@garry-w:~/devops_otus/garry_infra$ trytravis --repo https://github.com/Garry1287/trytravis.git
Remember that `trytravis` will make commits on your behalf to `https://github.com/Garry1287/trytravis.git`. Are you sure you wish to use this repository? Type `y` or `yes` to accept: y
Repository saved successfully.
```

Этот вариант больше понравился
```Для отладки тестов TravisCI утилитой trytravis необходимо было сделать fork репозитория и переименовать его в trytravis_ftaskaev_infra.
В .travis.yml добавим задание, которое будет срабатывать по условию if: branch = master:

jobs:
  include:
    - name: This should run only for master branch
      install:
        # Prepare bin directory
        - mkdir -p ${HOME}/bin ; export PATH=${PATH}:${HOME}/bin
        # Install terraform
        - curl --silent --output terraform.zip https://releases.hashicorp.com/terraform/0.12.8/terraform_0.12.8_linux_amd64.zip
        - unzip terraform.zip -d ${HOME}/bin
        - chmod +x ${HOME}/bin/terraform
        # Install tflint
        - curl --silent -L --output tflint.zip https://github.com/terraform-linters/tflint/releases/download/v0.12.1/tflint_linux_amd64.zip
        - unzip tflint.zip -d ${HOME}/bin
        - chmod +x ${HOME}/bin/tflint
        # Install ansible and ansible-lint
        - pip install --user ansible
        - pip install --user ansible-lint
      before_script:
        - packer --version
        - terraform --version
        - tflint --version
        - ansible --version
        - ansible-lint --version
      script:
        # Packer tests
        - packer validate -var-file=packer/variables.json.example packer/app.json
        - packer validate -var-file=packer/variables.json.example packer/db.json
        # Terraform tests
        - cd ${TRAVIS_BUILD_DIR}/terraform/stage ; terraform init -backend=false ; terraform validate
        - cd ${TRAVIS_BUILD_DIR}/terraform/prod  ; terraform init -backend=false ; terraform validate
        # Tflint tests
        - tflint ${TRAVIS_BUILD_DIR}/terraform/stage
        - tflint ${TRAVIS_BUILD_DIR}/terraform/prod
        # Ansible-lint tests
        - cd ${TRAVIS_BUILD_DIR}/ansible/playbooks ; ansible-lint *

      if: branch = master
```
Думаю что трушенее, но сделал через bash
































Курс DevOps 2019-08. Бортовой журнал. Часть 2. Microservices

Задания со звездочкой отмечаются в журнале литерой Ж. Во-первых, символ астериск занят, а во-вторых это немного символично. Самую малось, разумеется.
Docker-2 	Docker GCE 	D2 Ж 	D2 Задание Ж infra
Docker-2

• Создание docker host • Создание своего образа • Работа с Docker Hub
Установка docker

https://docs.docker.com/install/linux/docker-ce/ubuntu/ Установка docker prerequisites

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

Попытка добавить репозиторий: sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" # не для АРМ типа mint, собираем из пакетов: Установка из пакетов:

sudo dpkg -i docker-ce-cli_19.03.5~3-0~debian-stretch_amd64.deb 
sudo dpkg -i containerd.io_1.2.6-3_amd64.deb 
sudo dpkg -i docker-ce_19.03.5~3-0~debian-stretch_amd64.deb 

Проверка: docker version \ docker info Без повышения прав не показывает. sudo
Первый запуск docker

sudo docker run hello-world

• docker client запросил у docker engine запуск container из image hello-world • docker engine не нашел image hello-world локально и скачал его с Docker Hub • docker engine создал и запустил container изimage hello-world и передал docker client вывод stdout контейнера • Docker run каждый раз запускает новый контейнер • Если не указывать флаг --rm при запуске docker run, то после остановки контейнер вместе с содержимым остается на диске

Запустим docker образа ubuntu 16.04 c /bin/bash:

$ sudo docker run -it ubuntu:16.04 /bin/bash
Unable to find image 'ubuntu:16.04' locally
16.04: Pulling from library/ubuntu
e80174c8b43b: Pull complete 
d1072db285cc: Pull complete 
858453671e67: Pull complete 
3d07b1124f98: Pull complete 
Digest: sha256:bb5b48c7750a6a8775c74bcb601f7e5399135d0a06de004d000e05fd25c1a71c
Status: Downloaded newer image for ubuntu:16.04
root@f1791aaf1ee7:/# echo 'Hello world!' > /tmp/file
root@f1791aaf1ee7:/# exit
exit

Повторим запуск. Убедимся, что файл /tmp/file отсутствует:

$ sudo docker run -it ubuntu:16.04 /bin/bash
root@aa2bb4c515ce:/# cat /tmp/file
cat: /tmp/file: No such file or directory
root@aa2bb4c515ce:/# exit
exit

Выведем список контейнеров найдем второй по времени запуска:

$ sudo docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.CreatedAt}}\t{{.Names}}"
CONTAINER ID        IMAGE               CREATED AT                      NAMES
aa2bb4c515ce        ubuntu:16.04        2019-11-25 16:14:44 +0300 MSK   stoic_blackwell
f1791aaf1ee7        ubuntu:16.04        2019-11-25 16:10:52 +0300 MSK   happy_chandrasekhar
4dda79c8a3c0        hello-world         2019-11-25 15:59:06 +0300 MSK   gallant_austin

И войдем него:

$ sudo docker start f1791aaf1ee7  #  запуск уже имеющегося контейнера
f1791aaf1ee7
$ sudo docker attach f1791aaf1ee7 #  подключение к уже имеющемуся контейнеру
root@f1791aaf1ee7:/# 
root@f1791aaf1ee7:/# cat /tmp/file
Hello world!

Ctrl + p, Ctrl + q --> Escape sequence

• docker run => docker create + docker start + docker attach(требуется указать ключ -i) • docker create используется, когда не нужно стартовать контейнер сразу

Ключи запуска: • Через параметры передаются лимиты (cpu/mem/disk), ip, volumes • -i – запускает контейнер в foreground режиме (docker attach) • -d – запускаетконтейнерв background режиме • -t создает TTY • docker run -it ubuntu:16.04 bash • docker run -dt nginx:latest
Docker exec

docker exec запускает новый процесс внтури контейнера

sudo docker exec -it f1791aaf1ee7 bash
root@f1791aaf1ee7:/# ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0  18232  3256 pts/0    Ss+  13:17   0:00 /bin/bash
root        16  1.5  0.0  18232  3360 pts/1    Ss   13:32   0:00 bash
root        25  0.0  0.0  34420  2860 pts/1    R+   13:32   0:00 ps aux
root@f1791aaf1ee7:/# 

Docker commit

• Создает image из контейнера • Контейнер при этом остается запущенным

$ sudo docker commit f1791aaf1ee7 guildin/ubuntu-tmp-file
sha256:adaf9cefba52eb5f30e7ad034d9ce608c95a9d900a334504787d40a2540340be

$ sudo docker images
REPOSITORY                TAG                 IMAGE ID            CREATED              SIZE
guildin/ubuntu-tmp-file   latest              adaf9cefba52        About a minute ago   123MB
ubuntu                    16.04               5f2bf26e3524        3 weeks ago          123MB
hello-world               latest              fce289e99eb9        10 months ago        1.84kB

Docker kill, docker stop

• kill сразу посылает SIGKILL (безусловное завершение процесса) • stop посылает SIGTERM (останов), и через 10 секунд(настраивается) посылает SIGKILL

sudo docker ps -q                     #  вывод списка запущенных контейнеров 
sudo docker kill $(sudo docker ps -q) #  завершение процессов запущенных контейнеров.

docker system df

$ sudo docker system df
TYPE                TOTAL               ACTIVE              SIZE                RECLAIMABLE
Images              3                   2                   122.6MB             122.6MB (99%)
Containers          3                   0                   83B                 83B (100%)
Local Volumes       0                   0                   0B                  0B
Build Cache         0                   0                   0B                  0B

docker system df отображает количество дискового пространства, занятого образами, контейнерами и томами. Кросме того, отображается количество неиспользуемых ресурсов.
Docker rm & rmi

docker rm уничтожает контейнер, запущенный с ключом -f посылает sigkill работающему контейнеру и после удаляет его. docker rmi удаляет образ, если от него не запущены действующие контейнеры.















garry@garry-w:~/devops_otus/garry_mikroservices/docker-monilith$ docker run --name reddit2 -d --network=host garry1287/fotus-reddit:1.0
1c7086afd9170cc182d55f02ee6de27df9e1ac10d20057f92026bdc57eaea96e
garry@garry-w:~/devops_otus/garry_mikroservices/docker-monilith$ docker stop reddit
reddit
garry@garry-w:~/devops_otus/garry_mikroservices/docker-monilith$ docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                       SWARM   DOCKER     ERRORS
docker-host   *        google   Running   tcp://34.76.119.14:2376           v19.03.4   
garry@garry-w:~/devops_otus/garry_mikroservices/docker-monilith$ docker ps
CONTAINER ID        IMAGE                        COMMAND             CREATED             STATUS              PORTS               NAMES
1c7086afd917        garry1287/fotus-reddit:1.0   "/start.sh"         25 seconds ago      Up 23 seconds                           reddit2




docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/
projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \


Регион можно поменять на
docker-host
