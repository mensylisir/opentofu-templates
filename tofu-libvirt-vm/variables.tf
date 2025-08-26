variable "vm_count" {
  description = "Total number of VMs to create."
  type        = number
  default     = 6
}

variable "vm_base_name" {
  description = "Base name for the VMs. They will be named vm-base-name-1, vm-base-name-2, etc."
  type        = string
  default     = "node"
}

variable "base_image_path" {
  description = "Path to the base qcow2 image for VMs. This is the template image."
  type        = string
  default     = "/var/lib/libvirt/images/templates/jammy-server-cloudimg-amd64.img"
}

variable "vm_memory" {
  description = "Memory for each VM in MB."
  type        = number
  default     = 16384
}

variable "vm_vcpu" {
  description = "Number of virtual CPUs for each VM."
  type        = number
  default     = 8
}

variable "vm_disk_size" {
  description = "Disk size for each VM in GB."
  type        = number
  default     = 200
}

variable "ssh_user" {
  description = "The username to create in the VMs via cloud-init."
  type        = string
  default     = "mensyli1"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file (e.g., ~/.ssh/id_rsa.pub)."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "root_password" {
  description = "The password for the root user."
  type        = string
  #sensitive   = true
}

