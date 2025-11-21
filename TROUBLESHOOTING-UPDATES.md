# Troubleshooting Updates Summary

## Changes Made

This document summarizes the troubleshooting improvements added to the project.

### 1. Fixed API Routing Issue (Ingress Configuration)

**Problem:** Game loaded but showed "The string did not match the expected pattern" error when starting a game.

**Root Cause:** Ingress `rewrite-target` annotation was stripping the `/api` prefix from requests.

**Files Modified:**
- `k8s/ingress.yaml` - Removed rewrite-target annotation, simplified path matching
- `gitops-safe/base/ingress.yaml` - Updated for GitOps consistency
- `docs/08-troubleshooting.md` - Added detailed troubleshooting section

**Changes:**
```yaml
# BEFORE (incorrect):
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
paths:
  - path: /api(/|$)(.*)
    pathType: ImplementationSpecific

# AFTER (correct):
annotations:
  # Backend handles /api prefix, no rewrite needed
paths:
  - path: /api
    pathType: Prefix
```

### 2. Added Stuck Pod Cleanup to Recovery Script

**Problem:** After cluster restarts (especially on Mac), pods get stuck in "Terminating" state.

**Files Modified:**
- `scripts/recover-cluster.sh` - Added `cleanup_stuck_pods()` function
- `Makefile` - Updated recover-cluster description
- `docs/08-troubleshooting.md` - Added stuck pods troubleshooting entry

**New Function:**
```bash
cleanup_stuck_pods() {
    # Detects and force-deletes pods stuck in Terminating state
    # Runs automatically during cluster recovery
}
```

### 3. Updated Documentation

**Files Modified:**
- `docs/08-troubleshooting.md` - Added two new troubleshooting entries:
  1. **API routes return 404 or "Cannot POST"** - Detailed fix for ingress routing
  2. **Pods stuck in Terminating** - Quick fix for stuck pods

**New Troubleshooting Sections:**

#### API Routing Issue
- Symptom description
- Root cause explanation
- Diagnostic commands
- Step-by-step fix
- Testing verification
- GitOps update instructions

#### Stuck Terminating Pods
- Quick reference in table
- Command to check: `kubectl get pods -A | grep Terminating`
- Quick fix: Force delete or run `make recover-cluster`

### 4. Updated Hosts File Documentation

**Files Created:**
- `docs/hosts-setup.md` - Complete guide for configuring /etc/hosts with all service hostnames

**Includes:**
- Quick setup commands
- Individual entry commands
- Access URLs table with credentials
- Troubleshooting section
- DNS cache flush commands

### 5. ArgoCD Ingress Access

**Files Modified:**
- `docs/06-gitops.md` - Changed from port-forward to ingress-based access
- `docs/05-observability.md` - Added ArgoCD hostname to setup
- `scripts/setup-monitoring-ingress.sh` - Now adds argocd.gameapp.local
- `Makefile` - Updated URLs to use ingress
- `README.md` - Changed debugging commands to use ingress

**Benefits:**
- More stable than port-forwarding
- Consistent access pattern across all services
- Survives pod restarts
- Production-like setup

## Testing Performed

### API Routing Fix
```bash
# Test command
curl -X POST http://gameapp.local:8080/api/game/start \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser"}'

# Expected result
{"success":true,"message":"🎯 Game started!..."}
```

### Stuck Pods Cleanup
```bash
# Before fix: 8 pods stuck in Terminating
# After fix: All pods running healthy
kubectl get pods -A --field-selector=status.phase!=Running
# Result: No resources found
```

### ArgoCD Ingress Access
```bash
# Test command
curl -I http://argocd.gameapp.local:8080

# Expected result
HTTP/1.1 200 OK
```

## Files Ready for Commit

All changes have been tested and are ready to commit:

1. `k8s/ingress.yaml` - Fixed API routing
2. `scripts/recover-cluster.sh` - Added stuck pod cleanup
3. `Makefile` - Updated descriptions
4. `docs/08-troubleshooting.md` - Added new troubleshooting sections
5. `docs/hosts-setup.md` - New hosts configuration guide
6. `docs/06-gitops.md` - Updated ArgoCD access instructions
7. `docs/05-observability.md` - Added ArgoCD hostname
8. `docs/README.md` - Added hosts setup reference
9. `scripts/setup-monitoring-ingress.sh` - Added ArgoCD hostname
10. `README.md` - Updated debugging commands

## Recommended Commit Message

```
fix: Resolve API routing and add cluster recovery improvements

- Fix ingress rewrite breaking API routes (removes /api prefix issue)
- Add automatic stuck pod cleanup to cluster recovery script
- Update troubleshooting docs with detailed fixes
- Change ArgoCD access from port-forward to ingress
- Add comprehensive hosts file setup guide

Fixes game startup error "string did not match expected pattern"
Resolves pods stuck in Terminating after cluster restarts
```
