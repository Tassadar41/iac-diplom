terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.204.0"
    }
  }
}





resource "yandex_compute_instance" "vm_app" {
  name        = "vm-app"
  platform_id = "standard-v3"
  zone        = var.zone
  
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
    subnet_id          = var.subnet_id
    security_group_ids = [var.internal_sg_id]
    nat                = false
  }

  metadata_options {
    aws_v1_http_endpoint = 1
    aws_v1_http_token    = 2
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/vm-app-cloud-init.yaml.tpl", {
      monitoring_ip = var.monitoring_ip
      ssh_public_key      = var.ssh_public_key
    })
    //ssh-keys  = "yc-user:${var.ssh_public_key}"
  }
}
