#cloud-config

terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.2.1"
    }
  }
}

resource "incus_profile" "this" {
  name = var.name
  config = {
    "limits.cpu"    = tostring(var.cpu)
    "limits.memory" = var.ram
    "ipv4.address" = var.network_ip
    "cloud-init.user-data" = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      ssh_key = var.ssh_pubkey
    })
  }
  device {
    name = "root"
    type = "disk"
    properties = {
      pool = "default"
      path = "/"
      size = var.disk
    }
  }
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network
      "ipv4.address" = cidrhost(var.subnet, var.ip_offset + count.index)
    }
  }

}

resource "incus_instance" "this" {
  count    = var.count_nodes
  name     = "${var.name}-${count.index + 1}"
  image    = "${var.image_remote}:${var.image_name}"
  type     = var.type
  running  = var.power_state
  profiles = [incus_profile.this.name]
}