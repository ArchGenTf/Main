output "vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}

output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "ssh_private_key_pem" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "bastion_host_id" {
  value = azurerm_bastion_host.bastion.id
}
