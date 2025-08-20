#!/bin/bash
source config.env

echo "🔍 Checking OpenTelemetry deployment status..."
echo ""

# Check pod status
echo "Pod Status:"
kubectl get pods -n $NAMESPACE

echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE

echo ""
echo "Recent gateway logs:"
kubectl logs --tail=10 -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-kube-stack-gateway

echo ""
echo "Recent daemon logs:"
kubectl logs --tail=10 -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-kube-stack-daemon