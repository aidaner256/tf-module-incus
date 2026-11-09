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
  }))

  validation {
    condition = alltrue([
      for n in values(var.nodes) :
      (n.ips != null) != (n.count != null && n.ip_start != null)
    ])
    error_message = "Для каждой роли задай либо ips, либо count + ip_start (не оба и не ничего)."
  }
}
