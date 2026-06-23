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

variable "cluster_name" {
  description = "The name of the AKS cluster."
  type        = string
}

variable "dns_prefix" {
  description = "The DNS prefix for the private cluster."
  type        = string
}

variable "aks_subnet_id" {
  description = "The ID of the Spoke subnet where the cluster nodes will be placed."
  type        = string
}

variable "appgw_subnet_id" {
  description = "The ID of the Hub subnet where the Application Gateway (AGIC) will be created."
  type        = string
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the cluster."
  type        = string
  default     = "1.29"
}

variable "node_count" {
  description = "The number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "node_size" {
  description = "The VM size of the AKS cluster nodes."
  type        = string
  default     = "Standard_D2s_v5"
}
