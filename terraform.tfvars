# Данные лабы: топология и размеры. Код — в main.tf и modules/.

subnet     = "10.10.10.0/24"
dhcp_range = [200, 254]

shared_volume = {
  source   = "/home/mongo/shared"
  path     = "/mnt/shared"
  readonly = false
}

# На хосте ~6.7 GiB RAM: суммарно на ноды не больше ~5 GiB.
nodes = {
  # явный список
  k3s-master = {
    ips            = ["10.10.10.10"]
    cpu            = 2
    ram_mb         = 2048
    disk           = "15GiB"
    packages       = ["curl"]
    package_update = true
  }

  # диапазон: .20, .21, .22
  k3s-worker = {
    count          = 3
    ip_start       = 20
    cpu            = 1
    ram_mb         = 1024
    disk           = "10GiB"
    packages       = ["nano"]
    package_update = false
  }
}
