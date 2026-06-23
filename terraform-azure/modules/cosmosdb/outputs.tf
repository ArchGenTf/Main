output "cosmos_account_id" {
  value = azurerm_cosmosdb_account.cosmos.id
}

output "cosmos_account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "primary_mongodb_connection_string" {
  value     = azurerm_cosmosdb_account.cosmos.primary_mongodb_connection_string
  sensitive = true
}
