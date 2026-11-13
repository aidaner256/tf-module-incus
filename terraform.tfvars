# Данные лабы: топология и размеры. Код — в main.tf и modules/.

project = {
  name = "lab"
  limits = {
    "limits.memory"    = "5GiB" # на хосте ~6.7 GiB, остаток — хосту и MinIO
    "limits.instances" = "8"
  }
}

subnet     = "10.10.100.0/24"
dhcp_range = [200, 254]
dns_domain = "lab"
host_ip    = "192.168.1.242"

acl_enabled = true

# Снапшоты всех нод. Перед chaos-днём: snapshots = ["before-chaos"] -> apply.
# Откат одной ноды: incus snapshot restore --project lab k3s-worker-1 before-chaos
snapshots = []

forwards = [
  { description = "ingress http/https", listen_port = "80,443", target = "k3s-master-1" },
  { description = "k3s API", listen_port = "6443", target = "k3s-master-1" },
]

shared_volume = {
  source   = "/home/mongo/shared"
  path     = "/mnt/shared"
  readonly = false
}

nodes = {
  # явный список
  k3s-master = {
    ips            = ["10.10.100.10"]
    cpu            = 2
    ram_mb         = 2048
    disk           = "15GiB"
    packages       = ["nano", "curl", "openssh-server"]
    package_update = true
    runcmd         = ["apt update -y", "echo '123' > /tmp/123.txt", "modprobe overlay", "modprobe br_netfilter", "sysctl --system"]
    write_files = [
      { path = "/etc/sysctl.d/99-k3s.conf", content = "net.ipv4.ip_forward = 1\n" },
      { path = "/tmp/123", owner = "ansible:ansible", defer = true, permissions = "0755", source = "files/k3s/test.conf" },
    ]
    ingress = [
      { description = "k3s API, kubelet", from = ["k3s-worker"], protocol = "tcp", ports = "6443,10250" },
      { description = "flannel vxlan", from = ["k3s-worker"], protocol = "udp", ports = "8472" },
      { description = "MetalLB speakers", from = ["k3s-worker"], protocol = "tcp", ports = "7946" },
      { description = "MetalLB speakers", from = ["k3s-worker"], protocol = "udp", ports = "7946" },
      { description = "ping from workers", from = ["k3s-worker"], protocol = "icmp4" },
      { description = "LAN via forward", cidrs = ["192.168.1.0/24"], protocol = "tcp", ports = "80,443,6443" },
    ]
  }

  # диапазон: .20, .21, .22
  k3s-worker = {
    count          = 3
    ip_start       = 20
    cpu            = 1
    ram_mb         = 1024
    disk           = "10GiB"
    packages       = ["nano", "curl", "openssh-server"]
    package_update = false
    runcmd         = ["modprobe overlay", "modprobe br_netfilter", "sysctl --system"]
    write_files = [
      { path = "/etc/sysctl.d/99-k3s.conf", source = "files/k3s/99-k3s-sysctl.conf" }
    ]
    ingress = [
      { description = "kubelet", from = ["k3s-master"], protocol = "tcp", ports = "10250" },
      { description = "flannel vxlan", from = ["k3s-master"], protocol = "udp", ports = "8472" },
      { description = "MetalLB speakers", from = ["k3s-master"], protocol = "tcp", ports = "7946" },
      { description = "MetalLB speakers", from = ["k3s-master"], protocol = "udp", ports = "7946" },
      { description = "ping from master", from = ["k3s-master"], protocol = "icmp4" },
      { description = "LAN http/https", cidrs = ["192.168.1.0/24"], protocol = "tcp", ports = "80,443" },
    ]
  }

  # Пример на будущее (Patroni). Квота проекта: добавляя роль, проверь limits.memory.
  # pg = {
  #   count = 3, ip_start = 30, cpu = 1, ram_mb = 1024, disk = "10GiB"
  #   data_volume = { path = "/var/lib/postgresql" }
  #   ingress = [
  #     { description = "postgres", from = ["k3s-worker"], protocol = "tcp", ports = "5432" },
  #   ]
  # }
}
