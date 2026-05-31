#cloud-config
users:
  - name: yc-user
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - "${ssh_public_key}"


hostname: vm-app
fqdn: vm-app.production.local

write_files:
  - path: /etc/telegraf/telegraf.conf
    content: |
      [agent]
        interval = "10s"
        hostname = "vm-app"
      
      [[outputs.influxdb]]
        urls = ["http://${monitoring_ip}:8086"]
        database = "telegraf"
      
      [[inputs.cpu]]
      [[inputs.disk]]
      [[inputs.diskio]]
      [[inputs.mem]]
      [[inputs.net]]
      [[inputs.system]]
      [[inputs.processes]]

packages:
  - telegraf
  - podman
  - curl
  - wget
  - vim
  - htop

runcmd:
  # Start Telegraf
  - systemctl enable telegraf
  - systemctl start telegraf
  
  # Enable podman
  - systemctl enable podman.socket
  - systemctl start podman.socket

final_message: "Application VM setup complete."
