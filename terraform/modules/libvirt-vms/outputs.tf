output "names" {
  value = [for node in var.nodes : node.name]
}

output "ips" {
  value = { for node in var.nodes : node.name => node.ip }
}

output "macs" {
  value = { for node in var.nodes : node.name => node.mac }
}

output "uuids" {
  value = { for name, domain in libvirt_domain.node : name => domain.uuid }
}
