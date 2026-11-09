output "hosts" {
  description = "Роль => { имя ноды => IP }"
  value       = { for role, m in module.node : role => m.hosts }
}
