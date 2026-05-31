/*
output "bastion_public_ip" {
  value = yandex_vpc_address.bastion_public_ip.external_ipv4_address[0].address
}
*/
/*
output "bastion_public_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}
*/
output "bastion_public_ip" {
  value = data.yandex_vpc_address.bastion_public_ip.external_ipv4_address[0].address
}

output "bastion_local_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].ip_address
}
