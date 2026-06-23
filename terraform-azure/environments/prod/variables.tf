variable "subscription_id" {
  description = "The Azure Subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "The Azure AD Tenant ID."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group to create."
  type        = string
  default     = "rg-archgen-prod"
}

variable "location" {
  description = "The Azure region for prod resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "The environment name."
  type        = string
  default     = "prod"
}

variable "storage_account_name" {
  description = "The globally unique name of the Azure Storage Account."
  type        = string
}

variable "acr_name" {
  description = "The globally unique name of the Azure Container Registry."
  type        = string
}

variable "keyvault_name" {
  description = "The globally unique name of the Azure Key Vault."
  type        = string
}

variable "cosmos_account_name" {
  description = "The globally unique name of the Cosmos DB account."
  type        = string
}

variable "cluster_name" {
  description = "The name of the AKS cluster."
  type        = string
  default     = "aks-archgen-prod"
}
