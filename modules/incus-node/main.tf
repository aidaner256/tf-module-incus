terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.2.1"
    }
  }
}

locals {
  ram_mb = var.type == "virtual-machine" ? max(var.ram_mb, 1024) : var.ram_mb
}

resource "incus_profile" "this" {
  name = var.name

  config = merge({
    "limits.cpu"    = tostring(var.cpu)
    "limits.memory" = "${local.ram_mb}MiB"
    "cloud-init.user-data" = templatefile("${path.module}/cloud-init.yaml.tftpl",
      {
        init_user        = var.init_user
        ssh_key          = var.ssh_pubkey
        package_update   = var.package_update
        packages_install = var.packages_install
    })
    },
    var.type == "virtual-machine" ? { "security.secureboot" = tostring(var.secureboot) } : {}
  )

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = "default"
      path = "/"
      size = var.disk
    }
  }
}

resource "incus_instance" "this" {
  count    = length(var.ips)
  name     = "${var.name}-${count.index + 1}"
  image    = "${var.image_remote}:${var.image_name}"
  type     = var.type
  running  = var.power_state
  profiles = [incus_profile.this.name]

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = var.network
      "ipv4.address" = var.ips[count.index]
    }
  }
  dynamic "device" {
    for_each = var.shared_volume == null ? [] : [var.shared_volume]
    content {
      name = "shared-volume"
      type = "disk"
      properties = merge(
        {
          source   = device.value.source
          path     = device.value.path
          readonly = tostring(device.value.readonly)
        },
        var.type == "container" ? { shift = "true" } : {}
      )
    }
  }
  dynamic "device" {
    for_each = var.type == "virtual-machine" && var.tpm ? [1] : []
    content {
      name = "vtpm"
      type = "tpm"
      properties = {
        path = "/dev/tpm0"
      }
    }
  }
}
