terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "templates" {
  name = "tofu-templates"
  type = "dir"
  path = "/var/lib/libvirt/images/tofu-templates"
}

resource "libvirt_pool" "vms" {
  name = "tofu-vms"
  type = "dir"
  path = "/var/lib/libvirt/images/tofu-vms"
}

resource "libvirt_network" "tofu_net" {
  name      = "tofu-net"
  mode      = "nat"
  bridge    = "virbr-tofu"
  autostart = true
  addresses = ["192.168.150.0/24"]
  dhcp {
    enabled = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "libvirt_volume" "base_image" {
  name   = basename(var.base_image_path)
  pool   = libvirt_pool.templates.name
  source = var.base_image_path
  depends_on = [libvirt_pool.templates]
}

data "template_file" "user_data" {
  count    = var.vm_count
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    hostname       = "${var.vm_base_name}${count.index + 1}"
    ssh_user       = var.ssh_user
    root_password  = var.root_password
    ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  }
}

data "template_file" "meta_data" {
  count    = var.vm_count
  template = "instance-id: ${var.vm_base_name}${count.index + 1}\nlocal-hostname: ${var.vm_base_name}${count.index + 1}"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  count     = var.vm_count
  name      = "commoninit-${var.vm_base_name}${count.index + 1}.iso"
  pool      = libvirt_pool.vms.name
  user_data = data.template_file.user_data[count.index].rendered
  meta_data = data.template_file.meta_data[count.index].rendered
}

resource "libvirt_volume" "os_volume" {
  count          = var.vm_count
  name           = "${var.vm_base_name}${count.index + 1}.qcow2"
  pool           = libvirt_pool.vms.name
  base_volume_id = libvirt_volume.base_image.id
  size           = var.vm_disk_size * 1024 * 1024 * 1024
}

resource "libvirt_domain" "vms" {
  count      = var.vm_count
  name       = "${var.vm_base_name}${count.index + 1}"
  memory     = var.vm_memory
  vcpu       = var.vm_vcpu
  running    = true
  autostart  = true

  cpu {
    mode = "host-passthrough"
  }
  
  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  disk {
    volume_id = libvirt_volume.os_volume[count.index].id
  }

  network_interface {
    network_name   = libvirt_network.tofu_net.name
    wait_for_lease = true
  }

  depends_on = [libvirt_network.tofu_net]

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  lifecycle {
    create_before_destroy = true
  }
}
