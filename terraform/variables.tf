variable "image_path" {
  description = "Путь до базового qcow2 cloud-образа"
  type        = string
}

variable "ssh_user" {
  description = "Пользователь, создаваемый cloud-init"
  type        = string
  default     = "cloud-user"
}

variable "ssh_pubkey" {
  description = "Публичный ключ для ssh_user"
  type        = string
}

variable "network_name" {
  description = "Имя общей libvirt-сети"
  type        = string
  default     = "ha-net"
}

variable "network_domain" {
  description = "DNS-домен сети (dnsmasq отдаёт <host>.ha.local)"
  type        = string
  default     = "ha.local"
}
