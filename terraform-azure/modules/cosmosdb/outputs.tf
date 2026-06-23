output "cosmos_account_id" {
  value = azurerm_cosmosdb_account.cosmos.id
}

output "cosmos_account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "cosmos_connection_strings" {
  value     = azurerm_cosmosdb_account.cosmos.connection_strings
  sensitive = true
}
