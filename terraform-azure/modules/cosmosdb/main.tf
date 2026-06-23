resource "azurerm_cosmosdb_account" "cosmos" {
  name                          = var.cosmos_account_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  offer_type                    = "Standard"
  kind                          = "MongoDB"
  public_network_access_enabled = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableMongo"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-cosmos-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-cosmos-${var.environment}"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    subresource_names              = ["MongoDB"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-cosmos-${var.environment}"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  tags = {
    Environment = var.environment
  }
}
