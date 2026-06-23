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

variable "bastion_subnet_id" {
  description = "The ID of the AzureBastionSubnet."
  type        = string
}

variable "vm_subnet_id" {
  description = "The ID of the subnet where the jumpbox VM will be deployed."
  type        = string
}

variable "vm_size" {
  description = "The virtual machine size (SKU)."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "The administrator username for the jumpbox VM."
  type        = string
  default     = "praveen"
}
