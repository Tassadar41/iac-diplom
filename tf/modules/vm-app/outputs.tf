output "vm_app_local_ip" {
  value = yandex_compute_instance.vm_app.network_interface[0].ip_address
}
