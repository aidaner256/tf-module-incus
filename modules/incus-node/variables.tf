variable "name" {
  description = "Name to use across resources created"
  type        = string
}

variable "cpu" {
  description = "Max cpu req"
  type        = number
  default     = 1
}

variable "init_user" {
  description = "Basic user to login after installation"
  type        = string
  default     = "ansible"
}

variable "image" {
  description = "Образ: fingerprint (incus_image.x.fingerprint) или remote:alias"
  type        = string
}

variable "disk" {
  type    = string
  default = "10GiB"
}

variable "type" {
  description = "Can be container, or virtual-machine"
  type        = string
  default     = "container"
}

variable "ssh_pubkey" {
  type = string
}

variable "package_update" {
  type    = bool
  default = true
}

variable "packages_install" {
  description = "Packages to install via cloud-init"
  type        = list(string)
  default     = []
}

variable "network" {
  type = string
}

variable "ips" {
  description = "Static IPv4 per node, in order. Node count = length of this list."
  type        = list(string)

  validation {
    condition     = length(var.ips) > 0
    error_message = "ips must contain at least one address."
  }

  validation {
    condition     = alltrue([for ip in var.ips : can(cidrhost("${ip}/32", 0))])
    error_message = "Every entry in ips must be a plain IPv4 address, e.g. 10.10.10.11."
  }

  validation {
    condition     = length(distinct(var.ips)) == length(var.ips)
    error_message = "ips must not contain duplicates."
  }
}

variable "power_state" {
  type    = bool
  default = true
}

variable "secureboot" {
  type    = bool
  default = true
}

variable "tpm" {
  type        = bool
  description = "Trusted Platform Module"
  default     = false
}

variable "shared_volume" {
  type = object({
    source   = string
    path     = string
    readonly = optional(bool, true)
  })
  default = null
}

variable "ram_mb" {
  type    = number
  default = 1024
}

variable "disk_pool" {
  description = "Storage pool для root-диска"
  type        = string
  default     = "default"
}
variable "project" {
  description = "Incus-проект для профиля, инстансов, томов и снапшотов"
  type        = string
  default     = "default"
}

variable "acl" {
  description = "Имя network ACL для eth0. null — без файрвола."
  type        = string
  default     = null
}

variable "data_volume" {
  description = "Отдельный том под данные на каждую ноду. null — без тома."
  type = object({
    path = string
    size = optional(string)
  })
  default = null
}

variable "snapshots" {
  description = "Имена снапшотов, которые должны существовать у каждой ноды"
  type        = list(string)
  default     = []
}

variable "timezone" {
  type    = string
  default = "Etc/UTC"
}

variable "runcmd" {
  type    = list(string)
  default = []
}

variable "write_files" {
  description = "cloud-init write_files: содержимое уже прочитано в корне"
  type = list(object({
    path        = string
    content     = string
    permissions = string
    owner       = string
    defer       = bool
  }))
  default = []
}
