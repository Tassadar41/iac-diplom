terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.204.0"
    }
  }
}


resource "yandex_vpc_network" "production" {
  name        = "production-network"
  description = "Production VPC network"
}

resource "yandex_vpc_subnet" "private" {
  name           = "private-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.production.id
  v4_cidr_blocks = ["10.0.0.0/24"]  # Должно быть так, а не 0.0.0.0/0
  route_table_id = yandex_vpc_route_table.private_route.id
}

# Security group для бастиона
resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-sg"
  network_id = yandex_vpc_network.production.id

  ingress {
    protocol       = "TCP"
    description    = "App"
    port           = 30500
    v4_cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    protocol       = "TCP"
    description    = "SSH access port 22"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH доступ (порт 443 - альтернативный)
  ingress {
      protocol       = "TCP"
      description    = "SSH access port 443"
      port           = 443
      v4_cidr_blocks = ["0.0.0.0/0"]
  }


  # Kubernetes API
  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP/HTTPS
  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    protocol       = "TCP"
    description    = "Grafana"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Node exporter
  ingress {
    protocol       = "TCP"
    description    = "Node exporter"
    port           = 9100
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "Outbound traffic"

    v4_cidr_blocks = ["0.0.0.0/0"]
    //v4_cidr_blocks = ["10.0.0.0/24"]
  }
}

# Security group для внутренних узлов
resource "yandex_vpc_security_group" "internal_sg" {
  name       = "internal-sg"
  network_id = yandex_vpc_network.production.id

  # Внутренний трафик между сервисами
  ingress {
    protocol       = "TCP"
    description    = "Internal service traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }

  # SSH с бастиона
  ingress {
    protocol       = "TCP"
    description    = "SSH from bastion"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "Outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Статический маршрут для NAT из приватной сети
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private_route" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.production.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_subnet" "private_with_nat" {
  name           = "private-subnet-nat"
  zone           = var.zone
  network_id     = yandex_vpc_network.production.id
  v4_cidr_blocks = ["10.0.1.0/24"]  # Должно быть так, а не 0.0.0.0/0
  route_table_id = yandex_vpc_route_table.private_route.id
}


