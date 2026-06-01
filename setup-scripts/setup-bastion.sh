#!/bin/bash
set -e

# Ожидание освобождения блокировки dpkg с таймаутом и принудительной очисткой
echo "Checking for dpkg lock..."
MAX_WAIT=120  # максимальное время ожидания в секундах
WAITED=0
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "Timeout reached. Forcefully terminating blocking process..."
        # Получаем PID процесса, держащего блокировку
        PID=$(sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null | tr -d ' ')
        if [ -n "$PID" ]; then
            # Мягко завершаем
            sudo kill -TERM $PID 2>/dev/null
            sleep 3
            # Проверяем, жив ли ещё процесс
            if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                echo "Process still alive, force killing..."
                sudo kill -9 $PID 2>/dev/null
                sleep 1
            fi
        fi
        # Удаляем lock-файлы и донастраиваем пакеты
        echo "Cleaning up locks and repairing dpkg..."
        sudo rm -f /var/lib/dpkg/lock-frontend
        sudo rm -f /var/lib/dpkg/lock
        sudo dpkg --configure -a
        break
    fi
    echo "Waiting for other dpkg process to finish... (${WAITED}s elapsed)"
    sleep 5
    WAITED=$((WAITED + 5))
done


echo "=== Setting up Bastion Host ==="

# Удаляем все возможные старые репозитории и ключи InfluxDB/Telegraf
sudo rm -f /etc/apt/sources.list.d/influxdb.list
sudo rm -f /etc/apt/sources.list.d/influxdata.list
sudo rm -f /etc/apt/trusted.gpg.d/influxdb.gpg
sudo rm -f /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg
sudo rm -f /etc/apt/keyrings/influxdata-archive_compat.gpg


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
    server monitoring 10.0.0.3:3000 check

frontend k8s-api
    bind *:6443
    mode tcp
    default_backend k8s-masters

backend k8s-masters
    mode tcp
    balance roundrobin
    server master-1 10.0.0.22:6443 check
    server master-2 10.0.0.17:6443 check

EOF

# Перезапуск HAProxy
sudo systemctl restart haproxy
sudo systemctl enable haproxy

# Установка Telegraf (автоматическое разрешение конфликта influxdata.list)
echo "Installing Telegraf..."

# Полная очистка старых следов
sudo rm -f /etc/apt/sources.list.d/influxdb.list
sudo rm -f /etc/apt/sources.list.d/influxdata.list
sudo rm -f /etc/apt/trusted.gpg.d/influxdb.gpg
sudo rm -f /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg
sudo rm -f /usr/share/keyrings/influxdata-archive-keyring.gpg
sudo rm -f /etc/apt/trusted.gpg.d/influxdata.gpg

# Создаём .gnupg для root (исправлена опечатка)
sudo mkdir -p /root/.gnupg
sudo chmod 700 /root/.gnupg

# Добавляем ключ репозитория
wget -qO- "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xDA61C26A0585BD3B" | \
  gpg --dearmor | \
  sudo tee /etc/apt/trusted.gpg.d/influxdata.gpg > /dev/null
sudo chmod 644 /etc/apt/trusted.gpg.d/influxdata.gpg

# Временно создаём sources.list (иначе apt не увидит репозиторий)
echo "deb https://repos.influxdata.com/ubuntu jammy stable" | \
  sudo tee /etc/apt/sources.list.d/influxdata.list > /dev/null

sudo apt-get update

# Устанавливаем telegraf с флагом --force-confnew, чтобы автоматически принять
# версию influxdata.list из пакета influxdata-archive-keyring
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get install -y -o Dpkg::Options::="--force-confnew" telegraf

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