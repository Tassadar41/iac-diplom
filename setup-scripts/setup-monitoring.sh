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

echo "=== Setting up Monitoring VM ==="

# Обновление системы
sudo apt-get update
sudo apt-get upgrade -y

# Установка podman
echo "Installing podman..."
sudo apt-get install -y podman podman-docker

# Создание директории для мониторинга
sudo mkdir -p /opt/monitoring

# Создание docker-compose.yml
sudo tee /opt/monitoring/docker-compose.yml << 'EOF'
version: '3.8'

services:
  influxdb:
    image: influxdb:2.7
    container_name: influxdb
    restart: always
    ports:
      - "8086:8086"
    volumes:
      - influxdb_data:/var/lib/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=admin
      - DOCKER_INFLUXDB_INIT_PASSWORD=admin123
      - DOCKER_INFLUXDB_INIT_ORG=production
      - DOCKER_INFLUXDB_INIT_BUCKET=telegraf
      - DOCKER_INFLUXDB_INIT_RETENTION=30d

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource

volumes:
  influxdb_data:
  grafana_data:
EOF

# Запуск контейнеров
cd /opt/monitoring
sudo podman-compose up -d

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
  hostname = "vm-monitoring"

[[outputs.influxdb]]
  urls = ["http://localhost:8086"]
  database = "telegraf"

[[inputs.cpu]]
[[inputs.disk]]
[[inputs.diskio]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
[[inputs.processes]]
EOF

sudo systemctl restart telegraf
sudo systemctl enable telegraf

echo "=== Monitoring setup complete ==="