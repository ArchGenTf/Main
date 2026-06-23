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

variable "acr_name" {
  description = "The globally unique name of the Azure Container Registry."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID of the Spoke Endpoint subnet where the Private Endpoint will be created."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "The private DNS zone ID for ACR routing."
  type        = list(string)
}
