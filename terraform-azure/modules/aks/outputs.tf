output "cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "agic_identity_client_id" {
  value = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_relation[0].identity_client_id
}

output "agic_ingress_gateway_id" {
  value = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].gateway_id
}
