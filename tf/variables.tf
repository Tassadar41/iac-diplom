/*
variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}
*/

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "image_id" {
  type = string
}

variable "public_key_path" {
  type = string
}
variable "forlder_id_local" {
  type = string
}
variable "cloud_id" {
  type = string
}

variable "ssh_public_key" {
  description = "SSH Public Key for VMs"
  type        = string
}

variable "allowed_ssh_ip" {
  description = "IP allowed for SSH access (your IP)"
  type        = string
}

variable "service_account_name" {
  description = "Service account name"
  type        = string
  default     = "terraform-sa"
}

variable "bucket_name" {
  description = "Bucket for terraform state"
  type        = string
  default     = "terraform-state-production"
}