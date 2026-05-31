variable "folder_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "bastion_sg_id" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "allowed_ssh_ip" {
  type = string
}

variable "monitoring_local_ip" {
  type = string
}

variable "k8s_master_ips" {
  type = list(string)
}

variable "subnet_id_with_nat" {
  type = string
}
