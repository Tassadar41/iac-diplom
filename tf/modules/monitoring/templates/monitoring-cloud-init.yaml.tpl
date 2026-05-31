#cloud-config
users:
  - name: yc-user
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    enable-oslogin: "true"
    serial-port-enable: "1"
    ssh_authorized_keys:
      - "${ssh_public_key}"


hostname: vm-monitoring
fqdn: vm-monitoring.production.local