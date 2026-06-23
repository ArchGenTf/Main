# User-Assigned Managed Identity for the AKS Control Plane
resource "azurerm_user_assigned_identity" "aks" {
  name                = "identity-aks-controlplane-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = {
    Environment = var.environment
  }
}

# Private AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.cluster_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = var.dns_prefix
  kubernetes_version      = var.kubernetes_version
  private_cluster_enabled = true

  # Enable Workload Identity & OIDC Issuer
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name            = "default"
    node_count      = var.node_count
    vm_size         = var.node_size
    os_disk_size_gb = 50
    vnet_subnet_id  = var.aks_subnet_id

    # Required for Azure CNI
    type = "VirtualMachineScaleSets"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  # AGIC Addon Integration
  ingress_application_gateway {
    subnet_id    = var.appgw_subnet_id
    gateway_name = "appgw-agic-${var.environment}"
  }

  tags = {
    Environment = var.environment
  }
}
