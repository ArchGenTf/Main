output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}

output "vm_subnet_id" {
  value = azurerm_subnet.vm.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "endpoint_subnet_id" {
  value = azurerm_subnet.endpoints.id
}

output "vault_dns_zone_id" {
  value = azurerm_private_dns_zone.vault.id
}

output "vault_dns_zone_name" {
  value = azurerm_private_dns_zone.vault.name
}

output "cosmos_dns_zone_id" {
  value = azurerm_private_dns_zone.cosmos.id
}

output "cosmos_dns_zone_name" {
  value = azurerm_private_dns_zone.cosmos.name
}

output "acr_dns_zone_id" {
  value = azurerm_private_dns_zone.acr.id
}

output "acr_dns_zone_name" {
  value = azurerm_private_dns_zone.acr.name
}
