output "vpc_id" {
  value = yandex_vpc_network.production.id
}

output "subnet_id" {
  value = yandex_vpc_subnet.private.id
}

output "bastion_sg_id" {
  value = yandex_vpc_security_group.bastion_sg.id
}

output "internal_sg_id" {
  value = yandex_vpc_security_group.internal_sg.id
}

output "subnet_with_nat_id" {
  value = yandex_vpc_subnet.private_with_nat.id
}
