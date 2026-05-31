output "monitoring_local_ip" {
  value = yandex_compute_instance.monitoring.network_interface[0].ip_address
}
