resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
  }
}

# Network Module (Hub-Spoke architecture)
module "network" {
  source                   = "../../modules/network"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  environment              = var.environment
  hub_vnet_address_space   = ["10.20.0.0/16"]
  spoke_vnet_address_space = ["10.21.0.0/16"]
  bastion_subnet_prefix    = ["10.20.1.0/26"]
  vm_subnet_prefix         = ["10.20.2.0/27"]
  appgw_subnet_prefix      = ["10.20.3.0/26"]
  aks_subnet_prefix        = ["10.21.0.0/22"]
  endpoint_subnet_prefix   = ["10.21.4.0/27"]
}

# Storage Account Module (TF State file host)
module "storage" {
  source               = "../../modules/storage"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  environment          = var.environment
  storage_account_name = var.storage_account_name
  container_name       = "tfstate"
}

# Azure Container Registry Module
module "acr" {
  source               = "../../modules/acr"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  environment          = var.environment
  acr_name             = var.acr_name
  subnet_id            = module.network.endpoint_subnet_id
  private_dns_zone_ids = [module.network.acr_dns_zone_id]
}

# Key Vault Module
module "keyvault" {
  source               = "../../modules/keyvault"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  environment          = var.environment
  keyvault_name        = var.keyvault_name
  subnet_id            = module.network.endpoint_subnet_id
  private_dns_zone_ids = [module.network.vault_dns_zone_id]
  tenant_id            = var.tenant_id
}

# Cosmos DB Module (MongoDB API)
module "cosmosdb" {
  source               = "../../modules/cosmosdb"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  environment          = var.environment
  cosmos_account_name  = var.cosmos_account_name
  subnet_id            = module.network.endpoint_subnet_id
  private_dns_zone_ids = [module.network.cosmos_dns_zone_id]
}

# Bastion VM Host Module (Private Jumpbox Access)
module "bastion" {
  source              = "../../modules/bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  bastion_subnet_id   = module.network.bastion_subnet_id
  vm_subnet_id        = module.network.vm_subnet_id
}

# Private AKS Cluster with AGIC
module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  cluster_name        = var.cluster_name
  dns_prefix          = "aks-archgen-prod-dns"
  aks_subnet_id       = module.network.aks_subnet_id
  appgw_subnet_id     = module.network.appgw_subnet_id
  kubernetes_version  = "1.29"
  node_count          = 3                 # Production Node Count
  node_size           = "Standard_D4s_v5" # Larger VM SKU for Prod Nodes
}
