#!/bin/bash
set -e

echo "🚀 OpenTelemetry to Elastic Cloud Setup"
echo "======================================="

# Load configuration
if [ ! -f "config.env" ]; then
    echo "❌ Error: config.env file not found!"
    echo "Please copy config.env.example to config.env and fill in your Elastic Cloud details."
    exit 1
fi

source config.env

# Validate required variables
if [[ "$ELASTIC_OTLP_ENDPOINT" == *"YOUR_DEPLOYMENT_ID"* ]] || [[ "$ELASTIC_API_KEY" == *"YOUR_API_KEY"* ]]; then
    echo "❌ Error: Please update config.env with your actual Elastic Cloud details!"
    exit 1
fi

echo "📋 Configuration loaded:"
echo "   Endpoint: $ELASTIC_OTLP_ENDPOINT"
echo "   API Key: ${ELASTIC_API_KEY:0:20}..."
echo "   Namespace: $NAMESPACE"
echo ""

# Step 1: Delete existing secret
echo "🗑️  Step 1: Cleaning up existing secret..."
kubectl delete secret elastic-secret-otel --namespace $NAMESPACE 2>/dev/null || true

# Step 2: Create secret with user's deployment info
echo "🔐 Step 2: Creating Elastic Cloud secret..."
kubectl create secret generic elastic-secret-otel \
  --namespace $NAMESPACE \
  --from-literal=elastic_otlp_endpoint="$ELASTIC_OTLP_ENDPOINT" \
  --from-literal=elastic_api_key="$ELASTIC_API_KEY"

# Step 3: Initial deployment to create services
echo "⚙️  Step 3: Initial OpenTelemetry deployment..."
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
  --namespace $NAMESPACE \
  --create-namespace \
  --values fixed-logs-values.yaml \
  --version $HELM_CHART_VERSION

# Step 4: Wait for gateway service and get IP
# echo "🔍 Step 4: Waiting for gateway service..."
# kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-kube-stack-gateway -n $NAMESPACE --timeout=60s

GATEWAY_IP=$(kubectl get svc opentelemetry-kube-stack-gateway-collector -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "   Gateway IP: $GATEWAY_IP"

# Step 5: Inject the IP into values file
echo "💉 Step 5: Updating configuration with gateway IP..."
sed -i.bak "s/REPLACE_WITH_IP/$GATEWAY_IP/" fixed-logs-values.yaml

# Step 6: Final deployment with correct IP
echo "🚀 Step 6: Final deployment with correct configuration..."
helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
  --namespace $NAMESPACE \
  --values fixed-logs-values.yaml \
  --version $HELM_CHART_VERSION

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 To verify logs are flowing:"
echo "   1. Go to your Elastic Cloud console"
echo "   2. Navigate to Discover"
echo "   3. Look for logs with Kubernetes metadata"
echo ""
echo "🔍 To check pod status:"
echo "   kubectl get pods -n $NAMESPACE"
echo ""
echo "📝 To view logs:"
echo "   kubectl logs -f -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-kube-stack-gateway"

# Restore original values file
mv fixed-logs-values.yaml.bak fixed-logs-values.yaml