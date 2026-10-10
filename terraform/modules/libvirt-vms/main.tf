terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.9"
    }
  }
}

locals {
  nodes = { for node in var.nodes : node.name => node }
}

# COW-клон базового cloud-образа, по одному на ноду.
resource "libvirt_volume" "node" {
  for_each = local.nodes

  name     = "${each.value.name}.qcow2"
  pool     = "default"
  capacity = var.disk_size

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = pathexpand(var.image_path)

    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "ci" {
  for_each = local.nodes

  name = "${each.value.name}-cidata.iso"

  meta_data = <<-EOF
    instance-id: ${each.value.name}
    local-hostname: ${each.value.name}
  EOF

  user_data = templatefile("${path.module}/cloud-init.yaml.j2", {
    hostname   = each.value.name
    ssh_user   = var.ssh_user
    ssh_pubkey = var.ssh_pubkey
  })
}

resource "libvirt_domain" "node" {
  for_each = local.nodes

  name = each.value.name
  type = "kvm"

  memory     = var.memory
  memory_unit = "MiB"

  current_memory      = var.memory
  current_memory_unit = "MiB"

  vcpu           = var.vcpu
  vcpu_placement = "static"

  running   = true
  autostart = true

  cpu = {
    mode       = "host-passthrough"
    check      = "none"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"

    # Manual VM uses BIOS, not EFI/OVMF.
    boot_devices = [
      { dev = "hd" }
    ]
  }

  features = {
    acpi = true

    # <apic/>
    apic = {}

    # <vmport state="off"/>
    vm_port = {
      state = "off"
    }
  }

  clock = {
    offset = "utc"

    timer = [
      {
        name        = "rtc"
        tick_policy = "catchup"
      },
      {
        name        = "pit"
        tick_policy = "delay"
      },
      {
        name    = "hpet"
        present = "no"
      }
    ]
  }

  pm = {
    suspend_to_mem = {
      enabled = "no"
    }

    suspend_to_disk = {
      enabled = "no"
    }
  }

  on_poweroff = "destroy"
  on_reboot   = "restart"
  on_crash    = "destroy"

  devices = {
    channels = [
      {
        type = "unix"

        source = {
          unix = {
            mode = "bind"
          }
        }

        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]

    disks = [
      {
        # Main OS disk.
        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.node[each.key].name
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }

        # Important: the volume itself contains qcow2 data.
        driver = {
          name = "qemu"
          type = "qcow2"
        }
      },

      {
        # cloud-init NoCloud ISO.
        device = "cdrom"

        source = {
          file = {
            file = libvirt_cloudinit_disk.ci[each.key].path
          }
        }

        target = {
          dev = "sda"
          bus = "sata"
        }

        read_only = true

        driver = {
          name = "qemu"
          type = "raw"
        }
      }
    ]

    # Одна общая сеть; MAC берётся из списка нод.
    interfaces = [
      {
        source = {
          network = {
            network = var.network_name
          }
        }

        mac = {
          address = each.value.mac
        }

        model = {
          type = "virtio"
        }
      }
    ]

    serials = [
      {
        target = {
          type = "isa-serial"
          port = 0

          model = {
            name = "isa-serial"
          }
        }
      }
    ]

    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      }
    ]
  }
}
