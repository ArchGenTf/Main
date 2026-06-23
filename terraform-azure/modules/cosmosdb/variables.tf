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

variable "cosmos_account_name" {
  description = "The name of the Cosmos DB account."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where the Private Endpoint will be created."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "The private DNS zone ID for Cosmos DB routing."
  type        = list(string)
}
