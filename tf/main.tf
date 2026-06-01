resource "yandex_iam_service_account" "terraform_sa" {
  name        = var.service_account_name
  description = "Service account for Terraform and infrastructure"
}

resource "yandex_resourcemanager_folder_iam_member" "compute_admin" {
  folder_id = var.forlder_id_local
  role      = "compute.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc_admin" {
  folder_id = var.forlder_id_local
  role      = "vpc.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_admin" {
  folder_id = var.forlder_id_local
  role      = "k8s.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_admin" {
  folder_id = var.forlder_id_local
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_sa.id}"
}

# Статический ключ для хранения state
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.terraform_sa.id
  description        = "Static key for Object Storage access"
}

resource "yandex_storage_bucket" "terraform_state" {
  bucket = var.bucket_name
  
  anonymous_access_flags {
    read = false
    list = false
  }
}

# Модуль сети
module "network" {
  source = "./modules/network"
  allowed_ssh_ip = var.allowed_ssh_ip
  folder_id = var.forlder_id_local
  zone      = var.zone
}

# Модуль бастиона
module "bastion" {
  source = "./modules/bastion"
  
  folder_id            = var.forlder_id_local
  zone                 = var.zone
  subnet_id            = module.network.subnet_id
  bastion_sg_id        = module.network.bastion_sg_id
  ssh_public_key       = var.ssh_public_key
  allowed_ssh_ip       = var.allowed_ssh_ip
  monitoring_local_ip  = module.monitoring.monitoring_local_ip
  k8s_master_ips       = module.k8s_cluster.master_local_ips
  subnet_id_with_nat = module.network.subnet_with_nat_id
  
  depends_on = [module.network, module.monitoring, module.k8s_cluster]
}

# Модуль мониторинга
module "monitoring" {
  source = "./modules/monitoring"
  
  folder_id       = var.forlder_id_local
  zone            = var.zone
  subnet_id_with_nat = module.network.subnet_with_nat_id
  subnet_id       = module.network.subnet_id
  internal_sg_id  = module.network.internal_sg_id
  ssh_public_key  = var.ssh_public_key
  
  depends_on = [module.network]
}

# Модуль Kubernetes кластера
module "k8s_cluster" {
  source = "./modules/k8s-cluster"
  
  folder_id       = var.forlder_id_local
  zone            = var.zone
  subnet_id       = module.network.subnet_id
  internal_sg_id  = module.network.internal_sg_id
  ssh_public_key  = var.ssh_public_key
  monitoring_ip   = module.monitoring.monitoring_local_ip
  
  depends_on = [module.network, module.monitoring]
}

# Модуль дополнительной VM
/*
module "vm_app" {
  source = "./modules/vm-app"
  
  folder_id       = var.forlder_id_local
  zone            = var.zone
  subnet_id       = module.network.subnet_id
  internal_sg_id  = module.network.internal_sg_id
  ssh_public_key  = var.ssh_public_key
  monitoring_ip   = module.monitoring.monitoring_local_ip
  
  depends_on = [module.network, module.monitoring]
}
*/
