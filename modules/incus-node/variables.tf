variable "name" {
  description = "Name to use across resources created"
  type        = string
}

variable "cpu" {
  description = "Max cpu req"
  type        = number
  default     = 1
}

variable "image_name" {
  type    = string
  default = "debian/12/cloud"
}

variable "image_remote" {
  type    = string
  default = "images"
}

variable "disk" {
  type    = string
  default = "10GiB"
}

variable "ram" {
  type    = string
  default = "1GiB"
}

variable "type" {
  description = "Can be container, or virtual-machine"
  type        = string
  default     = "container"
}

variable "ssh_pubkey" {
  type = string
}

variable "network" {
  type = string
}

variable "network_ip" {
  type = string
}

variable "count_nodes" {
  type    = number
  default = 1
}

variable "power_state" {
  type = bool
  default = true
}