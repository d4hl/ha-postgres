output "vm_ips" {
  description = "IP-адреса ВМ: имя -> адрес"
  value       = { for node in local.all_nodes : node.name => node.ip }
}

output "vm_macs" {
  description = "MAC-адреса ВМ: имя -> MAC"
  value       = { for node in local.all_nodes : node.name => node.mac }
}

output "ips_by_group" {
  description = "IP-адреса по группам"
  value = {
    postgres = { for node in local.postgres_nodes : node.name => node.ip }
    etcd     = { for node in local.etcd_nodes : node.name => node.ip }
    haproxy  = { for node in local.haproxy_nodes : node.name => node.ip }
  }
}

output "keepalived_vip" {
  description = "VIP для keepalived (не выдаётся по DHCP)"
  value       = local.vip
}

output "ansible_inventory" {
  description = "Строки для секции [all] в ansible/inventory.ini"
  value = join("\n", [
    for node in local.all_nodes :
    format("%-8s ansible_host=%-15s ansible_user=%s", node.name, node.ip, var.ssh_user)
  ])
}
