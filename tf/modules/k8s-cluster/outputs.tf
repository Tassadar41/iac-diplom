output "master_local_ips" {
  value = yandex_compute_instance.k8s_master[*].network_interface[0].ip_address
}

output "worker_local_ips" {
  value = yandex_compute_instance.k8s_worker[*].network_interface[0].ip_address
}

