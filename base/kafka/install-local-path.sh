#!/bin/bash
set -e

echo "=== Installing local-path-provisioner ==="
echo ""

# Check if already installed
if kubectl get storageclass local-path >/dev/null 2>&1; then
    echo "✓ local-path storage class already exists"
else
    echo "Installing local-path-provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
    
    echo "Waiting for provisioner to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app=local-path-provisioner \
        -n local-path-storage \
        --timeout=60s
    
    echo "✓ local-path-provisioner installed"
fi

# Set as default storage class
echo ""
echo "Setting local-path as default storage class..."
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Storage Classes:"
kubectl get storageclass

echo ""
echo "Provisioner Pods:"
kubectl get pods -n local-path-storage

echo ""
echo "✓ Ready to deploy Kafka with persistent storage!"