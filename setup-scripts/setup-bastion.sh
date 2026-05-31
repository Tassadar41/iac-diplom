#!/bin/bash
set -e

echo "=== Setting up Bastion Host ==="

# Обновление системы
sudo apt-get update
sudo apt-get upgrade -y

# Установка HAProxy
echo "Installing HAProxy..."
sudo apt-get install -y haproxy

# Конфигурация HAProxy
sudo tee /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 5000
    timeout client 50000
    timeout server 50000

frontend grafana
    bind *:3000
    mode tcp
    default_backend monitoring-grafana

backend monitoring-grafana
    mode tcp
    server monitoring 10.0.0.4:3000 check

frontend k8s-api
    bind *:6443
    mode tcp
    default_backend k8s-masters

backend k8s-masters
    mode tcp
    balance roundrobin
    server master-1 10.0.0.11:6443 check
    server master-2 10.0.0.12:6443 check
    server master-3 10.0.0.23:6443 check
EOF

# Перезапуск HAProxy
sudo systemctl restart haproxy
sudo systemctl enable haproxy

# Установка Telegraf
echo "Installing Telegraf..."
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
echo "deb https://repos.influxdata.com/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
sudo apt-get update
sudo apt-get install -y telegraf

# Конфигурация Telegraf
sudo tee /etc/telegraf/telegraf.conf << 'EOF'
[agent]
  interval = "10s"
  hostname = "bastion"

[[outputs.influxdb]]
  urls = ["http://10.0.0.4:8086"]
  database = "telegraf"

[[inputs.cpu]]
[[inputs.disk]]
[[inputs.diskio]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
EOF

sudo systemctl restart telegraf
sudo systemctl enable telegraf

# Установка kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "=== Bastion setup complete ==="