output "storage_account_id" {
  value = azurerm_storage_account.state.id
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}
