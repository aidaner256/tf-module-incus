terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.2.1"
    }
  }

  backend "s3" {
    bucket                      = "tf-state"
    key                         = "states/terraform.tfstate"
    region                      = "us-east-1"
    profile                     = "default"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    use_lockfile                = true
    endpoints = {
      s3 = "http://localhost:9000"
    }
  }
}

provider "incus" {}

# ---------- Сеть ----------
# Сеть создана руками до Terraform: берём её под управление, а не создаём заново.
# После первого успешного apply этот блок можно удалить.
import {
  to = incus_network.lab
  id = "incusbr0"
}

resource "incus_network" "lab" {
  name = "incusbr0"
  config = {
    "ipv4.address"     = "${cidrhost(var.subnet, 1)}/${split("/", var.subnet)[1]}"
    "ipv4.nat"         = "true"
    "ipv4.dhcp.ranges" = "${cidrhost(var.subnet, var.dhcp_range[0])}-${cidrhost(var.subnet, var.dhcp_range[1])}"
    "ipv6.address"     = "none"
  }
}

# ---------- Образ ----------
# Скачивается один раз, все ноды создаются из него.
resource "incus_image" "debian" {
  source_image = {
    remote = "images"
    name   = "debian/12/cloud"
    type   = "virtual-machine"
  }
}

# ---------- Ноды ----------
# Старый вызов module "master" переехал в module "node" (for_each):
# переносим его профиль в state, чтобы Terraform не пытался создать дубль.
moved {
  from = module.master
  to   = module.node["k3s-master"]
}

module "node" {
  source   = "./modules/incus-node"
  for_each = var.nodes

  name = each.key
  # Либо явный список ips, либо диапазон count + ip_start (см. валидацию в variables.tf)
  ips = each.value.ips != null ? each.value.ips : [
    for i in range(each.value.count) : cidrhost(var.subnet, each.value.ip_start + i)
  ]
  cpu              = each.value.cpu
  ram_mb           = each.value.ram_mb
  disk             = each.value.disk
  packages_install = each.value.packages
  package_update   = each.value.package_update

  # Общее для всех нод
  network       = incus_network.lab.name
  image         = incus_image.debian.fingerprint
  type          = "virtual-machine"
  secureboot    = false
  init_user     = var.init_user
  ssh_pubkey    = file(pathexpand(var.ssh_pubkey_path))
  shared_volume = var.shared_volume
}
