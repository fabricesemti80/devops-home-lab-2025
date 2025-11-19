# Requirements Document

## Introduction

This document specifies requirements for setting up and managing a k3d Kubernetes cluster for the humor-game application. The system must provide a local development environment that mirrors production capabilities, including proper image management, networking configuration, and cluster lifecycle operations.

## Glossary

- **k3d**: A lightweight wrapper to run k3s (Rancher Lab's minimal Kubernetes distribution) in Docker
- **Cluster**: A k3d Kubernetes cluster instance running locally in Docker containers
- **Image Import**: The process of loading Docker images into the k3d cluster's containerd runtime
- **Load Balancer**: The k3d component that exposes cluster services on host ports
- **Registry**: A Docker registry for storing and distributing container images
- **Node**: A Docker container running as part of the k3d cluster (server or agent)

## Requirements

### Requirement 1

**User Story:** As a developer, I want to create a k3d cluster with proper configuration, so that I can run the humor-game application locally.

#### Acceptance Criteria

1. WHEN a developer executes the cluster creation command THEN the system SHALL create a cluster named "dev-cluster" with 1 server node and 2 agent nodes
2. WHEN the cluster is created THEN the system SHALL configure port 8080 on the host to map to port 80 on the load balancer
3. WHEN the cluster is created THEN the system SHALL configure port 8443 on the host to map to port 443 on the load balancer
4. WHEN the cluster is created THEN the system SHALL disable the default Traefik ingress controller
5. WHEN the cluster is created THEN the system SHALL configure the cluster to use the k3d-registry on port 5000

### Requirement 2

**User Story:** As a developer, I want to import locally built Docker images into the cluster, so that I can test my application without pushing to a remote registry.

#### Acceptance Criteria

1. WHEN a developer imports an image THEN the system SHALL verify the cluster "dev-cluster" exists before attempting import
2. WHEN importing the frontend image THEN the system SHALL load "humor-game-frontend:latest" into the cluster using the correct cluster name
3. WHEN importing the backend image THEN the system SHALL load "humor-game-backend:latest" into the cluster using the correct cluster name
4. IF the cluster does not exist THEN the system SHALL provide a clear error message indicating the cluster must be created first
5. WHEN an image import completes successfully THEN the system SHALL confirm the image is available in the cluster by listing images

### Requirement 3

**User Story:** As a developer, I want to verify the cluster is running correctly, so that I can ensure my environment is ready for development.

#### Acceptance Criteria

1. WHEN a developer checks cluster status THEN the system SHALL report whether the cluster "dev-cluster" exists
2. WHEN the cluster is running THEN the system SHALL display all node names with their roles, status, and IP addresses
3. WHEN the cluster is running THEN the system SHALL verify all nodes are in Ready state
4. WHEN checking cluster configuration THEN the system SHALL display the configured port mappings (8080:80 and 8443:443)
5. WHEN the cluster does not exist THEN the system SHALL provide the exact command to create it using k3d-config.yaml

### Requirement 4

**User Story:** As a developer, I want to delete and recreate the cluster, so that I can start fresh when needed.

#### Acceptance Criteria

1. WHEN a developer deletes the cluster THEN the system SHALL remove all cluster nodes and associated resources
2. WHEN deleting a cluster THEN the system SHALL preserve local Docker images on the host
3. WHEN the cluster is deleted THEN the system SHALL release all host ports that were mapped to the cluster
4. WHEN recreating a cluster THEN the system SHALL apply the configuration from k3d-config.yaml
5. IF the cluster does not exist during deletion THEN the system SHALL handle the operation gracefully without errors

### Requirement 5

**User Story:** As a developer, I want to build and import images in a single workflow, so that I can quickly iterate on code changes.

#### Acceptance Criteria

1. WHEN a developer triggers the build-and-import workflow THEN the system SHALL build the frontend Docker image
2. WHEN the frontend image build completes THEN the system SHALL build the backend Docker image
3. WHEN both images are built THEN the system SHALL import the frontend image into the cluster
4. WHEN the frontend import completes THEN the system SHALL import the backend image into the cluster
5. IF any step fails THEN the system SHALL report the failure and halt the workflow

### Requirement 6

**User Story:** As a developer, I want to list imported images in the cluster, so that I can verify which versions are available.

#### Acceptance Criteria

1. WHEN a developer lists cluster images THEN the system SHALL query all nodes for their loaded images
2. WHEN displaying images THEN the system SHALL show the image name and tag
3. WHEN displaying images THEN the system SHALL show the image size
4. WHEN displaying images THEN the system SHALL filter to show only humor-game related images
5. WHEN the cluster does not exist THEN the system SHALL provide a clear error message
