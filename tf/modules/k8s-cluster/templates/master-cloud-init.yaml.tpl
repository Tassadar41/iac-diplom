#cloud-config
users:
  - name: yc-user
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    enable-oslogin: "true"
    serial-port-enable: "1"
    ssh_authorized_keys:
      - "${ssh_public_key}"

hostname: ${node_name}
fqdn: ${node_name}.production.local

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

  - path: /etc/containerd/config.toml
    content: |
      version = 2
      [plugins]
        [plugins."io.containerd.grpc.v1.cri"]
          sandbox_image = "registry.k8s.io/pause:3.9"
          [plugins."io.containerd.grpc.v1.cri".containerd]
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
                runtime_type = "io.containerd.runc.v2"
                [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
                  SystemdCgroup = true

  - path: /etc/telegraf/telegraf.conf
    content: |
      [agent]
        interval = "10s"
        hostname = "${node_name}"
      
      [[outputs.influxdb]]
        urls = ["http://${monitoring_ip}:8086"]
        database = "telegraf"
      
      [[inputs.cpu]]
      [[inputs.disk]]
      [[inputs.diskio]]
      [[inputs.mem]]
      [[inputs.net]]
      [[inputs.system]]
      [[inputs.kubernetes]]
        url = "http://localhost:10255"

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - telegraf

runcmd:
  # Load kernel modules
  - modprobe overlay
  - modprobe br_netfilter
  
  # Apply sysctl params
  - sysctl --system
  
  # Disable swap
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab
  
  # Install containerd
  - apt-get update
  - apt-get install -y containerd
  
  # Configure containerd
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  
  # Install Kubernetes packages
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  
  # Start kubelet
  - systemctl enable kubelet
  - systemctl start kubelet
  
  # Start Telegraf
  - systemctl enable telegraf
  - systemctl start telegraf

final_message: "Kubernetes master node ${node_name} setup complete. Run kubeadm init on first master."
