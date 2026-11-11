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
  name    = var.name
  project = var.project

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
        timezone         = var.timezone
        runcmd           = var.runcmd
        write_files      = var.write_files
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

# Диск под данные: отдельный объект Incus, живёт независимо от VM
resource "incus_storage_volume" "data" {
  count = var.data_volume == null ? 0 : length(var.ips)

  name         = "${var.name}-${count.index + 1}-data"
  pool         = var.disk_pool
  project      = var.project
  content_type = "filesystem"
  config       = var.data_volume.size == null ? {} : { size = var.data_volume.size }
}

resource "incus_instance" "this" {
  count    = length(var.ips)
  name     = "${var.name}-${count.index + 1}"
  project  = var.project
  image    = var.image
  type     = var.type
  running  = var.power_state
  profiles = [incus_profile.this.name]


  # NIC на инстансе, а не в профиле: у каждой ноды свой статический IP
  device {
    name = "eth0"
    type = "nic"
    properties = merge(
      {
        network        = var.network
        "ipv4.address" = var.ips[count.index]
      },
      var.acl == null ? {} : {
        "security.acls"                        = var.acl
        "security.acls.default.ingress.action" = "reject"
        "security.acls.default.egress.action"  = "allow"
      }
    )
  }

  dynamic "device" {
    for_each = var.data_volume == null ? [] : [var.data_volume]
    content {
      name = "data"
      type = "disk"
      properties = {
        pool   = var.disk_pool
        source = incus_storage_volume.data[count.index].name
        path   = device.value.path
      }
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

# Снапшот = пара (нода, имя). Ключ вида "k3s-worker-1/before-chaos"
resource "incus_instance_snapshot" "this" {
  for_each = {
    for pair in setproduct(range(length(var.ips)), var.snapshots) :
    "${var.name}-${pair[0] + 1}/${pair[1]}" => { idx = pair[0], name = pair[1] }
  }

  instance = incus_instance.this[each.value.idx].name
  name     = each.value.name
  project  = var.project
  stateful = false
}
