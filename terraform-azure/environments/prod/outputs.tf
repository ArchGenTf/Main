output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_cluster_id" {
  value = module.aks.cluster_id
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "bastion_vm_private_ip" {
  value = module.bastion.vm_private_ip
}

output "ssh_private_key_pem" {
  value     = module.bastion.ssh_private_key_pem
  sensitive = true
}

output "keyvault_uri" {
  value = module.keyvault.keyvault_uri
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "cosmos_db_endpoint" {
  value = module.cosmosdb.cosmos_account_name
}
