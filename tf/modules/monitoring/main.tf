terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.204.0"
    }
  }
}




resource "yandex_compute_instance" "monitoring" {
  name        = "vm-monitoring"
  platform_id = "standard-v3"
  zone        = var.zone
  
  allow_stopping_for_update = true
  
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = "fd8498pb5smsd5ch4gid"
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    //subnet_id = var.subnet_id_with_nat
    subnet_id          = var.subnet_id
    security_group_ids = [var.internal_sg_id]
    nat                = false
  }

  metadata_options {
    aws_v1_http_endpoint = 1
    aws_v1_http_token    = 2
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/monitoring-cloud-init.yaml.tpl", {
      influxdb_admin_password = "influxdb_admin_password"  # Move to variables in production
      telegraf_password       = "telegraf_password"
      grafana_admin_password  = "grafana_admin_password"
      ssh_public_key      = var.ssh_public_key
    })
    //ssh-keys  = "yc-user:${var.ssh_public_key}"
  }
}
