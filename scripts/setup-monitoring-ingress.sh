#!/bin/bash

echo "🌐 Setting up Monitoring Ingress Access..."

# Apply the monitoring ingress
echo "📋 Applying monitoring ingress configuration..."
kubectl apply -f k8s/monitoring-ingress.yaml

# Wait for ingress to be ready
echo "⏳ Waiting for ingress to be ready..."
sleep 5

# Add local DNS entries to /etc/hosts
echo "📝 Adding local DNS entries to /etc/hosts..."

# Check if entries already exist
if ! grep -q "prometheus.gameapp.local" /etc/hosts; then
    echo "127.0.0.1 prometheus.gameapp.local" | sudo tee -a /etc/hosts
    echo "✅ Added prometheus.gameapp.local to /etc/hosts"
else
    echo "ℹ️  prometheus.gameapp.local already exists in /etc/hosts"
fi

if ! grep -q "grafana.gameapp.local" /etc/hosts; then
    echo "127.0.0.1 grafana.gameapp.local" | sudo tee -a /etc/hosts
    echo "✅ Added grafana.gameapp.local to /etc/hosts"
else
    echo "ℹ️  grafana.gameapp.local already exists in /etc/hosts"
fi

if ! grep -q "argocd.gameapp.local" /etc/hosts; then
    echo "127.0.0.1 argocd.gameapp.local" | sudo tee -a /etc/hosts
    echo "✅ Added argocd.gameapp.local to /etc/hosts"
else
    echo "ℹ️  argocd.gameapp.local already exists in /etc/hosts"
fi

# Check ingress status
echo "🔍 Checking ingress status..."
kubectl get ingress -n monitoring

echo ""
echo "🎉 Monitoring ingress setup complete!"
echo ""
echo "📊 Access your services:"
echo "   Prometheus: http://prometheus.gameapp.local:8080"
echo "   Grafana:    http://grafana.gameapp.local:8080"
echo "   ArgoCD:     http://argocd.gameapp.local:8080"
echo ""
echo "🔐 Credentials:"
echo "   Grafana - Username: admin, Password: admin123"
echo "   ArgoCD  - Username: admin, Password: (get with kubectl command)"
echo ""
echo "💡 Note: Make sure your k3d cluster is configured to expose port 8080"
echo "   Run: k3d cluster create --port 8080:80@loadbalancer"
