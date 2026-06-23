resource "azurerm_container_registry" "acr" {
  name                          = var.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false

  tags = {
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-acr-${var.environment}"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-acr-${var.environment}"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  tags = {
    Environment = var.environment
  }
}
