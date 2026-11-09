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
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    use_lockfile                = true
    region                      = "us-east-1"
    profile                     = "default"
    endpoints = {
      s3 = "http://localhost:9000"
    }
  }
}

provider "incus" {}


resource "incus_network" "lab" {
  name = "incusbr0"
  config = {
    "ipv4.address"     = "${cidrhost(local.subnet, 1)}/24"
    "ipv4.nat"         = "true"
    "ipv4.dhcp.ranges" = "${cidrhost(local.subnet, 200)}-${cidrhost(local.subnet, 254)}"
    "ipv6.address"     = "none"
  }
}

locals {
  subnet     = "10.10.10.0/24"
  ssh_pubkey = file(pathexpand("~/.ssh/id_rsa.pub"))
  init_user  = "ansible"

  common = {
    network    = incus_network.lab.name
    image      = incus_image.debian.fingerprint
    ssh_pubkey = local.ssh_pubkey
    type       = "virtual-machine"
  }
  nodes = {
    k3s-master = { count = 1, ip_start = 10, cpu = 2, ram_mb = 3072, disk = "15GiB" }
    k3s-worker = { count = 3, ip_start = 20, cpu = 1, ram_mb = 2048, disk = "10GiB" }
  }
}

resource "incus_image" "debian" {
  source_image = {
    remote = "images"
    name   = "debian/12/cloud"
    type   = "virtual-machine"
  }
}

module "node" {
  source   = "./modules/incus-node"
  for_each = local.nodes

  name   = each.key
  ips    = [for i in range(each.value.count) : cidrhost(local.subnet, each.value.ip_start + i)]
  cpu    = each.value.cpu
  ram_mb = each.value.ram_mb
  disk   = each.value.disk

  network     = incus_network.lab.name
  incus_image = incus_image.debian.fingerprint
  ssh_pubkey  = local.ssh_pubkey
  type        = "virtual-machine"
}