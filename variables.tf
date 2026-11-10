variable "project" {
  description = "Incus-проект лабы и его квоты (ключи limits.* из документации Incus)."
  type = object({
    name   = string
    limits = optional(map(string), {})
  })
}

variable "subnet" {
  description = "Подсеть лабы. Шлюз = .1, статика нод — ниже DHCP-диапазона."
  type        = string
  default     = "10.10.10.0/24"
}

variable "dhcp_range" {
  description = "Номера хостов [первый, последний], которые раздаёт DHCP. Статические IP нод сюда не попадают."
  type        = list(number)
  default     = [200, 254]
}

variable "dns_domain" {
  description = "Домен лабы: ноды резолвятся как <имя>.<домен>."
  type        = string
  default     = "lab"
}

variable "host_ip" {
  description = "IP хоста в LAN, на котором слушает network forward."
  type        = string
}

variable "acl_enabled" {
  description = "Включить файрвол между ролями. false — быстро снять все ACL, если что-то сломалось."
  type        = bool
  default     = true
}

variable "forwards" {
  description = "Проброс портов host_ip:listen_port -> нода:target_port."
  type = list(object({
    description = optional(string, "")
    protocol    = optional(string, "tcp")
    listen_port = string
    target      = string           # имя ноды, например k3s-master-1
    target_port = optional(string) # по умолчанию = listen_port
  }))
  default = []
}

variable "snapshots" {
  description = "Имена снапшотов для всех нод. Добавил имя + apply = снапшот; убрал имя + apply = снапшот удалён."
  type        = list(string)
  default     = []
}

variable "init_user" {
  type    = string
  default = "ansible"
}

variable "ssh_pubkey_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "shared_volume" {
  description = "Папка хоста, общая для всех нод. null — не монтировать."
  type = object({
    source   = string
    path     = string
    readonly = optional(bool, true)
  })
  default = null
}

variable "nodes" {
  description = "Роли нод. IP задаются либо явным списком ips, либо диапазоном count + ip_start."
  type = map(object({
    ips            = optional(list(string))
    count          = optional(number)
    ip_start       = optional(number)
    cpu            = number
    ram_mb         = number
    disk           = string
    packages       = optional(list(string), [])
    package_update = optional(bool, true)

    # Отдельный диск под данные на каждую ноду роли. Переживает пересоздание VM.
    data_volume = optional(object({
      path = string
      size = optional(string)
    }))

    # Кому, кроме хоста и нод той же роли, разрешено ходить на эту роль
    ingress = optional(list(object({
      description = optional(string, "")
      from        = optional(list(string), []) # роли-источники
      cidrs       = optional(list(string), []) # или подсети (например, LAN)
      protocol    = string                     # tcp / udp / icmp4
      ports       = optional(string)           # "6443" или "80,443" или "2379-2380"
    })), [])
  }))

  validation {
    condition = alltrue([
      for n in values(var.nodes) :
      (n.ips != null) != (n.count != null && n.ip_start != null)
    ])
    error_message = "Для каждой роли задай либо ips, либо count + ip_start (не оба и не ничего)."
  }
}
