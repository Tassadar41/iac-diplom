terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.204.0"
    }
  }
}




locals {
  bastion_name = "bastion"
}

data "yandex_vpc_address" "bastion_public_ip" {
  address_id = "e9bud7h23bvuv548rkb8"
  //name = "bastion-static-ip"
  /*
  name = "bastion-public-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
  */
}

resource "yandex_compute_instance" "bastion" {
  name        = local.bastion_name
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
      image_id = "fd8498pb5smsd5ch4gid" # yc-user 22.04 LTS
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = var.subnet_id_with_nat
    //subnet_id          = var.subnet_id

    security_group_ids = [var.bastion_sg_id]
    nat                = true
    nat_ip_address     = data.yandex_vpc_address.bastion_public_ip.external_ipv4_address[0].address
  }
  
  metadata_options {
    aws_v1_http_endpoint = 1
    aws_v1_http_token    = 2
  }
  
  # Cloud-init конфигурация
  metadata = {
    user-data = templatefile("${path.module}/templates/bastion-cloud-init.yaml.tpl", {
      monitoring_local_ip = var.monitoring_local_ip
      k8s_master_1_ip     = var.k8s_master_ips[0]
      k8s_master_2_ip     = var.k8s_master_ips[1]
      k8s_master_3_ip     = var.k8s_master_ips[2]
      influxdb_url        = "http://${var.monitoring_local_ip}:8086"
      ssh_public_key      = var.ssh_public_key
    })
    //ssh-keys  = "yc-user:${var.ssh_public_key}"
  }
}


/*
resource "yandex_vpc_address" "bastion_public_ip" {
  name = "bastion-public-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
}
*/
