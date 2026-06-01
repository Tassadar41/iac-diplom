
#cloud-config
password: Qwerty123!
chpasswd:
  expire: False
ssh_pwauth: True

hostname: bastion
fqdn: bastion.production.local

users:
  - name: yc-user
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - "${ssh_public_key}"

write_files:
  - path: /etc/ssh/sshd_config.d/port443.conf
    content: |
      Port 22
      Port 443

  - path: /etc/telegraf/telegraf.conf
    content: |
      [agent]
        interval = "10s"
        round_interval = true
        metric_batch_size = 1000
        metric_buffer_limit = 10000
        collection_jitter = "0s"
        flush_interval = "10s"
        flush_jitter = "0s"
        precision = ""
        debug = false
        quiet = false
        hostname = "bastion"
        omit_hostname = false
      
      [[outputs.influxdb]]
        urls = ["${influxdb_url}"]
        database = "telegraf"
        timeout = "5s"
        username = ""
        password = ""
      
      [[inputs.cpu]]
        percpu = true
        totalcpu = true
        collect_cpu_time = false
        report_active = false
      
      [[inputs.disk]]
        ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
      
      [[inputs.diskio]]
      [[inputs.mem]]
      [[inputs.net]]
      [[inputs.system]]
      [[inputs.swap]]
      [[inputs.netstat]]

  - path: /etc/haproxy/haproxy.cfg
    content: |
      global
        log /dev/log local0
        log /dev/log local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

      defaults
        log global
        mode tcp
        option tcplog
        option dontlognull
        timeout connect 5000
        timeout client 50000
        timeout server 50000

      frontend k8s-api
        bind *:6443
        mode tcp
        option tcplog
        default_backend k8s-masters

      backend k8s-masters
        mode tcp
        option tcp-check
        balance roundrobin
        server master-1 ${k8s_master_1_ip}:6443 check
        server master-2 ${k8s_master_2_ip}:6443 check
        

      frontend grafana
        bind *:3000
        mode tcp
        option tcplog
        default_backend monitoring-grafana

      backend monitoring-grafana
        mode tcp
        option tcp-check
        server monitoring ${monitoring_local_ip}:3000 check

packages:
  - haproxy
  - telegraf

runcmd:
  - echo "Port 22" >> /etc/ssh/sshd_config
  - echo "Port 443" >> /etc/ssh/sshd_config
  - systemctl restart sshd
  - sysctl -w net.ipv4.ip_forward=1
  - echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  - systemctl enable haproxy
  - systemctl start haproxy
  - systemctl enable telegraf
  - systemctl start telegraf

final_message: "Bastion setup complete. SSH on ports 22 and 443"
