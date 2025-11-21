# Local Hosts Configuration

## Quick Setup

Add these entries to your `/etc/hosts` file for local development:

```bash
# Add all required hostnames at once
sudo tee -a /etc/hosts << EOF
127.0.0.1 gameapp.local
127.0.0.1 prometheus.gameapp.local
127.0.0.1 grafana.gameapp.local
127.0.0.1 argocd.gameapp.local
EOF
```

## Individual Entries

If you prefer to add them one at a time:

```bash
# Main application
echo "127.0.0.1 gameapp.local" | sudo tee -a /etc/hosts

# Monitoring services
echo "127.0.0.1 prometheus.gameapp.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 grafana.gameapp.local" | sudo tee -a /etc/hosts

# GitOps management
echo "127.0.0.1 argocd.gameapp.local" | sudo tee -a /etc/hosts
```

## Access URLs

Once configured, access your services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Game App** | http://gameapp.local:8080 | None required |
| **Prometheus** | http://prometheus.gameapp.local:8080 | None required |
| **Grafana** | http://grafana.gameapp.local:8080 | admin / admin |
| **ArgoCD** | http://argocd.gameapp.local:8080 | admin / (see below) |

## Get ArgoCD Password

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

## Verify Configuration

Check that all entries are present:

```bash
grep "gameapp.local" /etc/hosts
```

Expected output:
```
127.0.0.1 gameapp.local
127.0.0.1 prometheus.gameapp.local
127.0.0.1 grafana.gameapp.local
127.0.0.1 argocd.gameapp.local
```

## Troubleshooting

### Entries already exist
If you see "already exists" messages, that's fine - the entries are already configured.

### Can't access services
1. Verify k3d cluster is running: `k3d cluster list`
2. Check ingress controller: `kubectl get pods -n ingress-nginx`
3. Verify ingress resources: `kubectl get ingress -A`
4. Test with curl: `curl -I http://gameapp.local:8080`

### DNS cache issues
If you recently added entries but they're not working:

```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches
```

## Why These Hostnames?

- **gameapp.local** - Main application (matches production pattern)
- **prometheus.gameapp.local** - Monitoring metrics (subdomain pattern)
- **grafana.gameapp.local** - Monitoring dashboards (subdomain pattern)
- **argocd.gameapp.local** - GitOps management (subdomain pattern)

This mirrors production DNS patterns where you'd have:
- `gameapp.games` (production domain)
- `prometheus.gameapp.games`
- `grafana.gameapp.games`
- `argocd.gameapp.games`
