variable "image_path" {
  description = "Путь до базового qcow2 cloud-образа"
  type        = string
}

variable "network_name" {
  description = "Имя общей libvirt-сети"
  type        = string
}

variable "nodes" {
  description = "Список ВМ: имя, MAC и IP"
  type = list(object({
    name = string
    mac  = string
    ip   = string
  }))
}

variable "ssh_user" {
  type    = string
  default = "cloud-user"
}

variable "ssh_pubkey" {
  type = string
}

variable "vcpu" {
  type    = number
  default = 2
}

variable "memory" {
  description = "MiB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Байты"
  type        = number
  default     = 20 * 1024 * 1024 * 1024
}
