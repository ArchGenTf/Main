variable "resource_group_name" {
  description = "The name of the resource group in which to create the network resources."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, prod)."
  type        = string
}

variable "hub_vnet_address_space" {
  description = "The address space for the Hub Virtual Network."
  type        = list(string)
}

variable "spoke_vnet_address_space" {
  description = "The address space for the Spoke Virtual Network."
  type        = list(string)
}

variable "bastion_subnet_prefix" {
  description = "The subnet prefix for the Bastion Host subnet (must be at least /26)."
  type        = list(string)
}

variable "vm_subnet_prefix" {
  description = "The subnet prefix for the Jumpbox VM subnet."
  type        = list(string)
}

variable "appgw_subnet_prefix" {
  description = "The subnet prefix for the Application Gateway subnet."
  type        = list(string)
}

variable "aks_subnet_prefix" {
  description = "The subnet prefix for the AKS cluster subnet."
  type        = list(string)
}

variable "endpoint_subnet_prefix" {
  description = "The subnet prefix for Private Endpoints subnet."
  type        = list(string)
}
