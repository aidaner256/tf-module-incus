output "instance_ip" {
  description = "IP-адреса созданных инстансов"
  value       = var.ips
  sensitive   = false
}
