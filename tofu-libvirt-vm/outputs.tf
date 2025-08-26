output "vm_ips" {
  description = "IP addresses of the created VMs."
  value = {
    for vm in libvirt_domain.vms :
    vm.name => vm.network_interface[0].addresses[0]
  }
}
