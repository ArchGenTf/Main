variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "The Azure region."
  type        = string
}

variable "environment" {
  description = "The environment name."
  type        = string
}

variable "keyvault_name" {
  description = "The name of the Azure Key Vault."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where the Private Endpoint will be created."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "The private DNS zone ID for Key Vault routing."
  type        = list(string)
}

variable "tenant_id" {
  description = "The Azure AD Tenant ID."
  type        = string
}
