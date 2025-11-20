#!/usr/bin/env bash
#
# k3d Cluster Recovery Script
# Automatically recovers k3d clusters after Mac restarts
#

set -euo pipefail

# Constants
readonly CLUSTER_NAME="${CLUSTER_NAME:-dev-cluster}"
readonly CONFIG_FILE="k3d-config.yaml"
readonly API_TIMEOUT=10
readonly NODE_READY_TIMEOUT=90
readonly CONTAINER_STOP_TIMEOUT=30
readonly CLUSTER_START_TIMEOUT=45
readonly RETRY_DELAY=10
readonly MAX_RETRIES=2

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}🔍 $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

log_progress() {
    echo -e "${BLUE}⏳ $*${NC}"
}

log_action() {
    echo -e "${GREEN}🚀 $*${NC}"
}

log_suggestion() {
    echo -e "${YELLOW}💡 $*${NC}"
}

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_CLUSTER_NOT_FOUND=1
readonly EXIT_RECOVERY_FAILED=2
readonly EXIT_RECREATION_NEEDED=3

#
# Cluster Status Detection Module
#

# Check if cluster exists
cluster_exists() {
    k3d cluster list 2>/dev/null | grep -q "^${CLUSTER_NAME}"
    return $?
}

# Check if cluster is running
cluster_is_running() {
    local running_count
    running_count=$(docker ps --filter "name=k3d-${CLUSTER_NAME}" --format "{{.Names}}" 2>/dev/null | wc -l)
    
    if [ "$running_count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Get cluster name from config file
get_cluster_name() {
    if [ -f "$CONFIG_FILE" ]; then
        # Try yq first, fallback to grep
        if command -v yq &> /dev/null; then
            yq eval '.metadata.name' "$CONFIG_FILE" 2>/dev/null || echo "dev-cluster"
        else
            grep -A 1 "metadata:" "$CONFIG_FILE" | grep "name:" | awk '{print $2}' || echo "dev-cluster"
        fi
    else
        echo "dev-cluster"
    fi
}

#
# Health Check Module
#

# Check if Kubernetes API server is responding
check_api_server() {
    log_progress "Checking API server..."
    
    # Give the API server more time to start up
    local max_wait=30
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if kubectl cluster-info &>/dev/null; then
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    return 1
}

# Check if all nodes are ready
check_nodes_ready() {
    log_progress "Checking node readiness..."
    
    # Get nodes with a background process to avoid hanging
    local nodes_output
    local temp_file="/tmp/k3d-nodes-$$"
    
    # Run kubectl in background with timeout
    (kubectl get nodes --no-headers 2>/dev/null > "$temp_file") &
    local kubectl_pid=$!
    
    # Wait up to 10 seconds for kubectl to complete
    local waited=0
    while [ $waited -lt 10 ]; do
        if ! kill -0 $kubectl_pid 2>/dev/null; then
            # Process completed
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done
    
    # Kill kubectl if still running
    kill -9 $kubectl_pid 2>/dev/null || true
    wait $kubectl_pid 2>/dev/null || true
    
    # Read the output if it exists
    if [ -f "$temp_file" ]; then
        nodes_output=$(cat "$temp_file")
        rm -f "$temp_file"
    else
        return 1
    fi
    
    # Check if we got any output
    if [ -z "$nodes_output" ]; then
        return 1
    fi
    
    # Check if all nodes are Ready
    local total_nodes
    local ready_nodes
    total_nodes=$(echo "$nodes_output" | wc -l | tr -d ' ')
    ready_nodes=$(echo "$nodes_output" | grep -c "Ready" || echo "0")
    
    if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Check container status for restart loops
check_container_status() {
    local container_name="k3d-${CLUSTER_NAME}-server-0"
    local status
    status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
    
    if [ "$status" = "restarting" ]; then
        return 1  # Restart loop detected
    else
        return 0  # Normal status
    fi
}

# Detect network interface errors in logs
detect_network_error() {
    local container_name="k3d-${CLUSTER_NAME}-server-0"
    local logs
    logs=$(docker logs "$container_name" 2>&1 | tail -50)
    
    if echo "$logs" | grep -q "failed to find interface with specified node ip"; then
        return 0  # Network error detected
    else
        return 1  # No network error
    fi
}

# Get comprehensive cluster health status
get_cluster_health() {
    local health_status="healthy"
    local issues=()
    
    if ! check_api_server; then
        health_status="unhealthy"
        issues+=("API server not responding")
    fi
    
    if ! check_nodes_ready; then
        health_status="unhealthy"
        issues+=("Nodes not ready")
    fi
    
    if ! check_container_status; then
        health_status="restart_loop"
        issues+=("Container in restart loop")
    fi
    
    if detect_network_error; then
        health_status="network_error"
        issues+=("Network interface error detected")
    fi
    
    echo "$health_status"
    
    if [ ${#issues[@]} -gt 0 ]; then
        for issue in "${issues[@]}"; do
            log_warning "$issue"
        done
    fi
}

#
# Network Recovery Module
#

# Stop cluster gracefully and wait for containers to stop
stop_cluster_gracefully() {
    log_action "Stopping cluster gracefully..."
    k3d cluster stop "$CLUSTER_NAME" 2>/dev/null || true
    
    # Wait for containers to fully stop
    log_progress "Waiting for all containers to stop..."
    local wait_time=0
    while [ $wait_time -lt $CONTAINER_STOP_TIMEOUT ]; do
        local running_count
        running_count=$(docker ps --filter "name=k3d-${CLUSTER_NAME}" --format "{{.Names}}" 2>/dev/null | wc -l)
        
        if [ "$running_count" -eq 0 ]; then
            log_success "Cluster stopped successfully"
            # Give it a few more seconds to fully clean up
            sleep 3
            return 0
        fi
        sleep 2
        wait_time=$((wait_time + 2))
    done
    
    log_warning "Cluster stop timeout reached, but continuing..."
    return 0
}

# Start cluster with retry logic
start_cluster_with_retry() {
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log_action "Starting cluster (attempt $attempt/$MAX_RETRIES)..."
        
        if k3d cluster start "$CLUSTER_NAME" 2>/dev/null; then
            log_progress "Waiting for nodes to become ready (up to 90s)..."
            
            # Wait for nodes to be ready with progress dots
            local wait_time=0
            while [ $wait_time -lt $NODE_READY_TIMEOUT ]; do
                if check_nodes_ready 2>/dev/null; then
                    echo ""  # New line after dots
                    log_success "Cluster started successfully"
                    return 0
                fi
                echo -n "."
                sleep 5
                wait_time=$((wait_time + 5))
            done
            
            echo ""  # New line after dots
            log_warning "Nodes not ready after ${NODE_READY_TIMEOUT}s timeout"
            
            # If this wasn't the last attempt, do a full stop before retry
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_info "Stopping cluster before retry..."
                stop_cluster_gracefully
                log_progress "Waiting ${RETRY_DELAY}s before retry..."
                sleep $RETRY_DELAY
            fi
        else
            log_warning "Cluster start failed"
            if [ $attempt -lt $MAX_RETRIES ]; then
                log_progress "Waiting ${RETRY_DELAY}s before retry..."
                sleep $RETRY_DELAY
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Verify network configuration
verify_network_config() {
    log_progress "Verifying network configuration..."
    
    # Check if load balancer is accessible
    if docker ps --filter "name=k3d-${CLUSTER_NAME}-serverlb" --format "{{.Names}}" | grep -q "serverlb"; then
        log_success "Load balancer is running"
        return 0
    else
        log_warning "Load balancer not found"
        return 1
    fi
}

#
# Recovery Orchestrator
#

# Simple restart recovery
simple_restart() {
    log_action "Attempting simple restart..."
    
    # If cluster is already running but unhealthy, stop it first
    if cluster_is_running; then
        log_info "Cluster is running but unhealthy, stopping first..."
        stop_cluster_gracefully
    fi
    
    if start_cluster_with_retry; then
        if check_api_server; then
            log_success "Simple restart successful!"
            return 0
        fi
    fi
    
    return 1
}

# Network recovery
network_recovery() {
    log_warning "Network interface error detected"
    log_info "Mac restarts can cause network interface changes"
    log_action "Attempting network recovery..."
    
    if stop_cluster_gracefully; then
        if start_cluster_with_retry; then
            if check_api_server; then
                log_success "Network recovery successful!"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Restart loop recovery
restart_loop_recovery() {
    log_warning "Container restart loop detected"
    log_action "Attempting restart loop recovery..."
    
    if stop_cluster_gracefully; then
        if start_cluster_with_retry; then
            if check_api_server; then
                log_success "Restart loop recovery successful!"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Report cluster not found
report_cluster_not_found() {
    log_error "Cluster '${CLUSTER_NAME}' does not exist"
    echo ""
    log_suggestion "Create the cluster with:"
    echo "  make setup-cluster"
    echo ""
    echo "Or manually:"
    echo "  k3d cluster create --config ${CONFIG_FILE}"
}

# Report network error
report_network_error() {
    log_error "Network interface error detected"
    echo ""
    log_info "This commonly happens after Mac restarts when network interfaces change"
    log_info "The cluster containers are trying to use an old network interface"
}

# Report recreation needed
report_recreation_needed() {
    log_error "All recovery attempts failed"
    echo ""
    log_warning "Cluster recreation may be necessary"
    log_suggestion "To recreate the cluster:"
    echo "  k3d cluster delete ${CLUSTER_NAME}"
    echo "  k3d cluster create --config ${CONFIG_FILE}"
    echo ""
    log_warning "Note: This will remove all deployed applications"
}

# Validate cluster health after recovery
validate_cluster_health() {
    log_progress "Validating cluster health..."
    
    local all_healthy=true
    
    # Check nodes
    if check_nodes_ready; then
        log_success "All nodes are Ready"
    else
        log_warning "Some nodes are not Ready"
        all_healthy=false
    fi
    
    # Check API server
    if check_api_server; then
        log_success "API server is responding"
    else
        log_warning "API server is not responding"
        all_healthy=false
    fi
    
    # Check load balancer
    if verify_network_config; then
        log_success "Load balancer is accessible"
    else
        log_warning "Load balancer issues detected"
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        return 0
    else
        return 1
    fi
}

# Report success
report_success() {
    echo ""
    log_success "Cluster recovery completed successfully!"
    echo ""
    log_info "Cluster Status:"
    kubectl get nodes 2>/dev/null || true
    echo ""
    log_info "Your cluster is ready to use"
}

#
# Main Recovery Workflow
#

main() {
    echo ""
    log_info "k3d Cluster Recovery Tool"
    log_info "Cluster: ${CLUSTER_NAME}"
    echo ""
    
    # Step 1: Check if cluster exists
    log_progress "Checking if cluster exists..."
    if ! cluster_exists; then
        report_cluster_not_found
        exit $EXIT_CLUSTER_NOT_FOUND
    fi
    log_success "Cluster exists"
    
    # Step 2: Check if cluster is running
    log_progress "Checking if cluster is running..."
    if cluster_is_running; then
        log_info "Cluster is already running"
        
        # Check health
        local health_status
        health_status=$(get_cluster_health)
        
        if [ "$health_status" = "healthy" ]; then
            log_success "Cluster is healthy"
            report_success
            exit $EXIT_SUCCESS
        else
            log_warning "Cluster is running but unhealthy: $health_status"
        fi
    else
        log_info "Cluster is stopped"
    fi
    
    # Step 3: Try simple restart
    echo ""
    if simple_restart; then
        if validate_cluster_health; then
            report_success
            exit $EXIT_SUCCESS
        fi
    fi
    
    # Step 4: Check for network errors and try network recovery
    echo ""
    if detect_network_error; then
        report_network_error
        if network_recovery; then
            if validate_cluster_health; then
                report_success
                exit $EXIT_SUCCESS
            fi
        fi
    fi
    
    # Step 5: Check for restart loops and try restart loop recovery
    echo ""
    if ! check_container_status; then
        if restart_loop_recovery; then
            if validate_cluster_health; then
                report_success
                exit $EXIT_SUCCESS
            fi
        fi
    fi
    
    # Step 6: All recovery attempts failed
    echo ""
    report_recreation_needed
    exit $EXIT_RECREATION_NEEDED
}

# Run main function
main "$@"
