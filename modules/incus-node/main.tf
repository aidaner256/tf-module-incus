terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.2"
    }
  }
}

locals {
  # VM нужно минимум 1 GiB: своё ядро + cloud-init
  ram_mb = var.type == "virtual-machine" ? max(var.ram_mb, 1024) : var.ram_mb
}

resource "incus_profile" "this" {
  name = var.name

  config = merge(
    {
      "limits.cpu"     = tostring(var.cpu)
      "limits.memory"  = "${local.ram_mb}MiB"
      "boot.autostart" = "true"
      "cloud-init.user-data" = templatefile("${path.module}/cloud-init.yaml.tftpl", {
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
      pool = var.disk_pool
      path = "/"
      size = var.disk
    }
  }

  # TPM только для VM; у VM путь /dev/tpm0 гостевое ядро создаёт само
  dynamic "device" {
    for_each = var.type == "virtual-machine" && var.tpm ? [1] : []
    content {
      name       = "vtpm"
      type       = "tpm"
      properties = {}
    }
  }
}

resource "incus_instance" "this" {
  count    = length(var.ips)
  name     = "${var.name}-${count.index + 1}"
  image    = var.image
  type     = var.type
  running  = var.power_state
  profiles = [incus_profile.this.name]

  # NIC на инстансе, а не в профиле: у каждой ноды свой статический IP
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
        # shift (перевод UID/GID) нужен только непривилегированным контейнерам
        var.type == "container" ? { shift = "true" } : {}
      )
    }
  }
}
