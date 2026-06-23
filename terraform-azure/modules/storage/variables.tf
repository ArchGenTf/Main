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

variable "storage_account_name" {
  description = "The globally unique name of the Azure Storage Account."
  type        = string
}

variable "container_name" {
  description = "The name of the storage container."
  type        = string
}
