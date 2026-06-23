#!/bin/bash
# Full cluster bootstrap: ArgoCD, CSI, ingress-nginx, Prometheus/Grafana, ArgoCD apps
set -e

echo "=== Step 1: Patch ArgoCD to LoadBalancer ==="
kubectl patch svc argocd-server -n argocd --type merge -p '{"spec":{"type":"LoadBalancer"}}'

echo "=== Step 2: Install CSI Secrets Store Driver ==="
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts 2>/dev/null || true
helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts 2>/dev/null || true
helm repo update
helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true \
  --wait --timeout 3m
helm upgrade --install azure-csi-provider csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
  --namespace kube-system \
  --wait --timeout 3m
echo "CSI installed"

echo "=== Step 3: Install ingress-nginx for dev ==="
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
helm upgrade --install ingress-nginx-dev ingress-nginx/ingress-nginx \
  --namespace ingress-nginx-dev \
  --set controller.ingressClassResource.name=nginx-dev \
  --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx-dev" \
  --set controller.ingressClass=nginx-dev \
  --set controller.service.type=LoadBalancer \
  --wait --timeout 5m
echo "ingress-nginx-dev installed"

echo "=== Step 4: Install ingress-nginx for prod ==="
helm upgrade --install ingress-nginx-prod ingress-nginx/ingress-nginx \
  --namespace ingress-nginx-prod \
  --set controller.ingressClassResource.name=nginx-prod \
  --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx-prod" \
  --set controller.ingressClass=nginx-prod \
  --set controller.service.type=LoadBalancer \
  --wait --timeout 5m
echo "ingress-nginx-prod installed"

echo "=== Step 5: Install Prometheus + Grafana ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.adminPassword=ArchGen@2024! \
  --wait --timeout 5m
echo "Prometheus + Grafana installed"

echo "=== Step 6: Get LoadBalancer IPs ==="
echo "Waiting for IPs..."
sleep 30
echo "ArgoCD IP:"
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo "Dev ingress IP:"
kubectl get svc -n ingress-nginx-dev -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
echo ""
echo "Prod ingress IP:"
kubectl get svc -n ingress-nginx-prod -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
echo ""
echo "Grafana IP:"
kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo "=== Bootstrap complete ==="
