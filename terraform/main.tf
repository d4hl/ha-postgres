terraform {
  required_version = ">= 1.5"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

locals {
  postgres_nodes = [
    { name = "pg-01", mac = "52:54:00:01:01:00", ip = "192.168.100.111" },
    { name = "pg-02", mac = "52:54:00:01:02:00", ip = "192.168.100.112" },
    { name = "pg-03", mac = "52:54:00:01:03:00", ip = "192.168.100.113" },
  ]

  etcd_nodes = [
    { name = "etcd-01", mac = "52:54:00:02:01:00", ip = "192.168.100.121" },
    { name = "etcd-02", mac = "52:54:00:02:02:00", ip = "192.168.100.122" },
    { name = "etcd-03", mac = "52:54:00:02:03:00", ip = "192.168.100.123" },
  ]

  haproxy_nodes = [
    { name = "ha-01", mac = "52:54:00:03:01:00", ip = "192.168.100.131" },
    { name = "ha-02", mac = "52:54:00:03:02:00", ip = "192.168.100.132" },
    { name = "ha-03", mac = "52:54:00:03:03:00", ip = "192.168.100.133" },
  ]

  all_nodes = concat(local.postgres_nodes, local.etcd_nodes, local.haproxy_nodes)

  # suggested VIP for keepalived, not used in terraform logic
  vip = "192.168.100.100"
}

resource "libvirt_network" "ha" {
  name      = var.network_name
  autostart = true

  forward = {
    mode = "nat"
  }

  domain = {
    name       = var.network_domain
    local_only = "yes"
  }

  dns = {
    host = [
      for node in local.all_nodes : {
        ip = node.ip
        hostnames = [
          { hostname = node.name },
          { hostname = "${node.name}.${var.network_domain}" },
        ]
      }
    ]
  }

  ips = [
    {
      address = "192.168.100.1"
      prefix  = 24

      dhcp = {
        # lease static
        hosts = [
          for node in local.all_nodes : {
            mac  = node.mac
            ip   = node.ip
            name = node.name
          }
        ]

        # dncp
        ranges = [
          { start = "192.168.100.150", end = "192.168.100.254" }
        ]
      }
    }
  ]
}

module "postgres" {
  source = "./modules/libvirt-vms"

  image_path   = var.image_path
  network_name = libvirt_network.ha.name
  nodes        = local.postgres_nodes

  ssh_user   = var.ssh_user
  ssh_pubkey = var.ssh_pubkey

  vcpu      = 2
  memory    = 2048
  disk_size = 20 * 1024 * 1024 * 1024
}

module "etcd" {
  source = "./modules/libvirt-vms"

  image_path   = var.image_path
  network_name = libvirt_network.ha.name
  nodes        = local.etcd_nodes

  ssh_user   = var.ssh_user
  ssh_pubkey = var.ssh_pubkey

  vcpu      = 2
  memory    = 2048
  disk_size = 20 * 1024 * 1024 * 1024
}

module "haproxy" {
  source = "./modules/libvirt-vms"

  image_path   = var.image_path
  network_name = libvirt_network.ha.name
  nodes        = local.haproxy_nodes

  ssh_user   = var.ssh_user
  ssh_pubkey = var.ssh_pubkey

  vcpu      = 2
  memory    = 2048
  disk_size = 20 * 1024 * 1024 * 1024
}
