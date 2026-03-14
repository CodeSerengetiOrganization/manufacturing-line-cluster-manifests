### Very Important Note ###
# This file has an issue, if run this file and it only create the Kafka server but no kafka topics,
# you need to manually create topics by apply all the files in `topics` folder.
# the reason is: when the command line to create topics, the kafka server is not yet ready.
#!/bin/bash
set -e  # Exit immediately if any command fails

# --- Configuration ---
NAMESPACE="machine-monitoring"
KAFKA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRIMZI_NAMESPACE="strimzi"
# Helm release name (used by helm upgrade/install and cleanup-kafka.sh helm uninstall)
STRIMZI_OPERATOR_NAME="strimzi-kafka-operator"
# Deployment name created by the Strimzi Helm chart (used for "already installed" and readiness checks)
STRIMZI_CLUSTER_OPERATOR_DEPLOYMENT="strimzi-cluster-operator"

echo "--- Starting Kafka Deployment with Strimzi Operator (KRaft Mode) ---"
echo "Note: Ensure namespace '${NAMESPACE}' is created via base/namespace/namespace-machine-monitoring.yaml"

# Step 1: Install Strimzi Cluster Operator
echo ""
echo "Step 1: Installing Strimzi Cluster Operator..."
echo "================================================"

# Check if Strimzi operator is already installed (chart creates Deployment named strimzi-cluster-operator)
if kubectl get deployment "${STRIMZI_CLUSTER_OPERATOR_DEPLOYMENT}" -n "${STRIMZI_NAMESPACE}" >/dev/null 2>&1; then
    echo "Strimzi operator already installed in namespace '${STRIMZI_NAMESPACE}'"
else
    echo "Installing Strimzi Cluster Operator..."
    
    # Create namespace for Strimzi operator if it doesn't exist
    kubectl create namespace "${STRIMZI_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Strimzi Helm repository
    if ! helm repo list | grep -q strimzi; then
        echo "Adding Strimzi Helm repository..."
        helm repo add strimzi https://strimzi.io/charts/
    fi
    
    echo "Updating Helm repositories..."
    helm repo update
    
    # Install Strimzi Cluster Operator
    echo "Installing Strimzi Cluster Operator via Helm..."
    # Install without --wait to avoid timeout issues; we'll use kubectl wait instead
    helm upgrade --install "${STRIMZI_OPERATOR_NAME}" strimzi/strimzi-kafka-operator \
        --namespace "${STRIMZI_NAMESPACE}" \
        --create-namespace \
        --set watchAnyNamespace=true
    
    echo "Waiting for Strimzi operator to be ready..."
    echo "This may take a few minutes..."
    
    # Wait for deployment to exist first (chart creates strimzi-cluster-operator)
    echo "Waiting for deployment to be created..."
    for i in {1..30}; do
        if kubectl get deployment "${STRIMZI_CLUSTER_OPERATOR_DEPLOYMENT}" -n "${STRIMZI_NAMESPACE}" >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
    
    # Now wait for pod to be ready
    kubectl wait --for=condition=ready pod \
        -l name=strimzi-cluster-operator \
        --timeout=300s \
        --namespace="${STRIMZI_NAMESPACE}" || {
        echo ""
        echo "WARNING: Strimzi operator did not become ready within 5 minutes"
        echo ""
        echo "Checking operator deployment status..."
        kubectl get deployment "${STRIMZI_CLUSTER_OPERATOR_DEPLOYMENT}" -n "${STRIMZI_NAMESPACE}" || true
        echo ""
        echo "Checking operator pods..."
        kubectl get pods -n "${STRIMZI_NAMESPACE}" -l name=strimzi-cluster-operator || true
        echo ""
        echo "Checking pod events..."
        kubectl get events -n "${STRIMZI_NAMESPACE}" --sort-by='.lastTimestamp' | tail -10 || true
        echo ""
        echo "To diagnose further, run:"
        echo "  kubectl describe pod -l name=strimzi-cluster-operator -n ${STRIMZI_NAMESPACE}"
        echo "  kubectl logs -l name=strimzi-cluster-operator -n ${STRIMZI_NAMESPACE}"
        exit 1
    }
    
    echo "✓ Strimzi Cluster Operator installed successfully"
fi

# Step 2: Deploy Kafka cluster using Strimzi
echo ""
echo "Step 2: Deploying Kafka cluster..."
echo "==================================="
cd "${KAFKA_DIR}"

# Ensure namespace exists
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Check if storage class exists (required for persistent volumes)
STORAGE_CLASS="local-path"
echo "Checking if storage class '${STORAGE_CLASS}' exists..."
if ! kubectl get storageclass "${STORAGE_CLASS}" >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Storage class '${STORAGE_CLASS}' not found!"
    echo ""
    echo "Available storage classes:"
    kubectl get storageclass || echo "  (none found)"
    echo ""
    echo "To fix this, you can:"
    echo "  1. Install local-path-provisioner (common in k3s):"
    echo "     kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml"
    echo ""
    echo "  2. Or update kafka-node-pool.yaml to use an existing storage class"
    echo "     (change 'class: local-path' to match an available storage class)"
    echo ""
    exit 1
else
    echo "✓ Storage class '${STORAGE_CLASS}' found"
fi

# Apply Kafka cluster resources using kustomize
echo "Applying Kafka cluster resources (Kafka CRD and KafkaNodePool)..."
kubectl apply -k "${KAFKA_DIR}/kafka-cluster"

# Wait for Kafka cluster to be ready
echo "Waiting for Kafka cluster to become ready..."
echo "This may take a few minutes..."

# Wait for Kafka resource to be ready
kubectl wait --for=condition=Ready kafka/kafka \
    --timeout=300s \
    --namespace="${NAMESPACE}" || {
    echo ""
    echo "WARNING: Kafka cluster did not become ready within 3 minutes"
    echo ""
    echo "Checking Kafka cluster status..."
    kubectl get kafka -n "${NAMESPACE}"
    echo ""
    echo "Checking pods..."
    kubectl get pods -n "${NAMESPACE}" -l strimzi.io/cluster=kafka
    echo ""
    echo "Check Kafka resource details:"
    echo "  kubectl describe kafka kafka -n ${NAMESPACE}"
    echo ""
    echo "Check pod logs:"
    echo "  kubectl logs -l strimzi.io/cluster=kafka -n ${NAMESPACE}"
    exit 1
}

# Apply Kafka topics using kustomize (now that cluster is ready)
echo ""
echo "Applying Kafka topics..."
kubectl apply -k "${KAFKA_DIR}/topics"
echo "✓ Topics applied (Topic Operator will create them in the cluster)"

# Step 3: Verify deployment
echo ""
echo "Step 3: Verifying Kafka deployment..."
echo "======================================"

# Get Kafka pods (Strimzi uses strimzi.io/cluster label)
echo "Kafka Pods:"
kubectl get pods -n "${NAMESPACE}" -l strimzi.io/cluster=kafka

echo ""
echo "Kafka Services:"
kubectl get svc -n "${NAMESPACE}" -l strimzi.io/cluster=kafka

echo ""
echo "Kafka Cluster Status:"
kubectl get kafka -n "${NAMESPACE}"

echo ""
echo "Kafka Topics Status:"
kubectl get kafkatopic -n "${NAMESPACE}"

# Step 4: Display connection information
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Kafka Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Kafka Bootstrap Server (for clients within cluster):"
echo "  kafka-kafka-bootstrap.${NAMESPACE}.svc.cluster.local:9092"
echo ""
echo "Or use the shorter form:"
echo "  kafka-kafka-bootstrap.${NAMESPACE}:9092"
echo ""
echo "To check Kafka cluster status:"
echo "  kubectl get kafka -n ${NAMESPACE}"
echo ""
echo "To check Kafka pods:"
echo "  kubectl get pods -n ${NAMESPACE} -l strimzi.io/cluster=kafka"
echo ""
echo "To check Kafka logs:"
echo "  kubectl logs -l strimzi.io/cluster=kafka -n ${NAMESPACE}"
echo ""
echo "To describe Kafka cluster:"
echo "  kubectl describe kafka kafka -n ${NAMESPACE}"
echo ""
echo "To check Kafka topics:"
echo "  kubectl get kafkatopic -n ${NAMESPACE}"
echo ""
echo "To describe Kafka topics:"
echo "  kubectl describe kafkatopic manufacturing-results-topic -n ${NAMESPACE}"
echo "  kubectl describe kafkatopic manufacturing-failures-topic -n ${NAMESPACE}"
echo ""
echo "To verify topics comprehensively (CRD + Broker level):"
echo "  ./verify-topics.sh"
echo ""
