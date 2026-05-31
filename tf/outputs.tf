output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = module.bastion.bastion_public_ip
}

output "grafana_url" {
  description = "Grafana URL through bastion"
  value       = "http://${module.bastion.bastion_public_ip}:3000"
}

output "influxdb_endpoint" {
  description = "InfluxDB internal endpoint"
  value       = "http://${module.monitoring.monitoring_local_ip}:8086"
}

output "k8s_api_endpoint" {
  description = "Kubernetes API endpoint through bastion"
  value       = "https://${module.bastion.bastion_public_ip}:6443"
}

output "ssh_bastion_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -J ubuntu@${module.bastion.bastion_public_ip} ubuntu@<internal-ip>"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "scp -r ubuntu@${module.bastion.bastion_public_ip}:~/.kube/config ~/.kube/config-prod"
}

output "monitoring_local_ip" {
  description = "Monitoring VM local IP"
  value       = module.monitoring.monitoring_local_ip
}

output "master_ips" {
  description = "Kubernetes master nodes IPs"
  value       = module.k8s_cluster.master_local_ips
}

output "worker_ips" {
  description = "Kubernetes worker nodes IPs"
  value       = module.k8s_cluster.worker_local_ips
}

output "vm_app_local_ip" {
  description = "Application VM local IP"
  value       = module.vm_app.vm_app_local_ip
}