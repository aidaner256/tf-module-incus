output "hosts" {
  description = "Имя ноды => IP"
  value       = { for i, inst in incus_instance.this : inst.name => var.ips[i] }
}
