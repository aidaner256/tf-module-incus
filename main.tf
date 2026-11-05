terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.2.1"
    }
  }
}
provider "incus" {}

module "test" {
  source      = "./modules/incus-node"
  name        = "test"
  count_nodes = 1
  network     = "incusbr0"
  ssh_pubkey  = file(pathexpand("~/.ssh/id_rsa.pub"))
  power_state = true
  type = "container"
  image_name = "alpine/3.23/cloud"
  network_ip = "10.10.10.168"
}