output "hosts" {
  description = "Роль => { имя ноды => IP }"
  value       = { for role, m in module.node : role => m.hosts }
}

output "dns_names" {
  description = "Имена нод внутри лабы"
  value       = [for name in keys(local.all_hosts) : "${name}.${var.dns_domain}"]
}
