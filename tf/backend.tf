/*
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "terraform-state-production"
    region = "ru-central1"
    key    = "infrastructure/terraform.tfstate"
    
    # Отключаем проверки AWS-специфичных параметров
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    
    # Явно указываем, что используем path-style адресацию
    use_path_style = true
  }
}
*/