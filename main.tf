terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 1.2.1"
    }
  }

  backend "s3" {
    bucket                      = "tf-state"
    key                         = "states/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    use_lockfile                = true
  }
}

provider "incus" {
  accept_remote_certificate    = true
  default_remote               = "lab-tf-incus-module"
  generate_client_certificates = true
  remote {
    name    = "lab-tf-incus-module"
    address = "https://${var.incus_ip}:${var.incus_port}"
    token   = var.incus_token
  }
}

locals {
  gateway = cidrhost(var.subnet, 1)

  # IP каждой роли считаются один раз и используются везде: модули, ACL, forward
  node_ips = {
    for role, n in var.nodes : role => (
      n.ips != null ? n.ips : [for i in range(n.count) : cidrhost(var.subnet, n.ip_start + i)]
    )
  }

  # имя ноды => IP (k3s-master-1 => 10.10.10.10)
  all_hosts = merge([
    for role, ips in local.node_ips : { for i, ip in ips : "${role}-${i + 1}" => ip }
  ]...)
}

# ---------- Проект ----------
# Изоляция лабы и квота: Incus не даст создать ноды сверх limits.memory.
# Сети, ACL и forward остаются в default-проекте (features.networks = false).
resource "incus_project" "lab" {
  name        = var.project.name
  description = "Lab: k3s / Patroni"
  config = merge(
    {
      "features.images"          = "true"
      "features.profiles"        = "true"
      "features.storage.volumes" = "true"
      "features.networks"        = "false"
    },
    var.project.limits
  )
}

# ---------- Сеть ----------
resource "incus_network" "lab" {
  name = "incusbr0"
  config = {
    "ipv4.address"     = "${local.gateway}/${split("/", var.subnet)[1]}"
    "ipv4.nat"         = "true"
    "ipv4.dhcp.ranges" = "${cidrhost(var.subnet, var.dhcp_range[0])}-${cidrhost(var.subnet, var.dhcp_range[1])}"
    "ipv6.address"     = "none"
    # DNS внутри лабы: dnsmasq бриджа резолвит <имя-ноды>.<dns_domain>
    "dns.domain" = var.dns_domain
  }
}

# ---------- Файрвол между ролями ----------
# На каждую роль свой ACL на вход. Всегда разрешено: хост (шлюз) и ноды той же роли.
# Остальное — только то, что перечислено в nodes.<роль>.ingress. Выход не ограничен.
resource "incus_network_acl" "role" {
  for_each = var.acl_enabled ? var.nodes : {}

  name        = "${each.key}-in"
  description = "Ingress for role ${each.key}"

  ingress = concat(
    [
      {
        action           = "allow"
        state            = "enabled"
        description      = "host / admin"
        source           = local.gateway
        protocol         = null
        destination_port = null
      },
      {
        action           = "allow"
        state            = "enabled"
        description      = "peers of ${each.key}"
        source           = join(",", local.node_ips[each.key])
        protocol         = null
        destination_port = null
      },
    ],
    [
      for r in each.value.ingress : {
        action           = "allow"
        state            = "enabled"
        description      = r.description
        source           = join(",", concat(flatten([for role in r.from : local.node_ips[role]]), r.cidrs))
        protocol         = r.protocol
        destination_port = r.ports
      }
    ]
  )

  lifecycle {
    precondition {
      condition     = alltrue(flatten([for r in each.value.ingress : [for role in r.from : contains(keys(var.nodes), role)]]))
      error_message = "В ingress.from роли ${each.key} указана несуществующая роль."
    }
  }
}

# ---------- Проброс портов с IP хоста ----------
resource "incus_network_forward" "lab" {
  count = length(var.forwards) > 0 ? 1 : 0

  network        = incus_network.lab.name
  listen_address = var.host_ip
  description    = "LAN -> lab"

  ports = [
    for f in var.forwards : {
      description    = f.description
      protocol       = f.protocol
      listen_port    = f.listen_port
      target_address = local.all_hosts[f.target]
      target_port    = coalesce(f.target_port, f.listen_port)
    }
  ]

  lifecycle {
    precondition {
      condition     = alltrue([for f in var.forwards : contains(keys(local.all_hosts), f.target)])
      error_message = "forwards.target должен быть именем ноды, например k3s-master-1."
    }
  }
}

# ---------- Образ ----------
resource "incus_image" "debian" {
  project = incus_project.lab.name
  source_image = {
    remote = "images"
    name   = "debian/12/cloud"
    type   = "virtual-machine"
  }
}

# ---------- Ноды ----------
module "node" {
  source   = "./modules/incus-node"
  for_each = var.nodes

  name             = each.key
  ips              = local.node_ips[each.key]
  cpu              = each.value.cpu
  ram_mb           = each.value.ram_mb
  disk             = each.value.disk
  packages_install = each.value.packages
  package_update   = each.value.package_update
  data_volume      = each.value.data_volume
  runcmd           = each.value.runcmd
  write_files = [for f in each.value.write_files : {
    path        = f.path
    content     = f.content != null ? f.content : file("${path.root}/${f.source}")
    permissions = f.permissions
    owner       = f.owner
    defer       = f.defer
  }]

  # Общее для всех нод
  project       = incus_project.lab.name
  network       = incus_network.lab.name
  acl           = var.acl_enabled ? incus_network_acl.role[each.key].name : null
  image         = incus_image.debian.fingerprint
  type          = "virtual-machine"
  secureboot    = false
  init_user     = var.init_user
  ssh_pubkey    = file(pathexpand(var.ssh_pubkey_path))
  shared_volume = var.shared_volume
  snapshots     = var.snapshots
}
