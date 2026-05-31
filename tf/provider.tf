terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.204.0"
    }
  }
}


provider "yandex" {
  cloud_id = var.cloud_id
  folder_id = var.forlder_id_local
  service_account_key_file = "E:/Project/iac-diplom/tf/key.json"
}