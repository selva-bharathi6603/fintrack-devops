#!/usr/bin/env bash
# deploy.sh — Build, scan, and deploy FinTrack to Minikube
# Usage: DOCKERHUB_USER=yourname ./scripts/deploy.sh

set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-your-dockerhub-username}"
IMAGE_NAME="${DOCKERHUB_USER}/fintrack"
BUILD_TAG="${BUILD_NUMBER:-local-$(date +%Y%m%d%H%M%S)}"

echo "════════════════════════════════════════════════════"
echo "  🚀 FinTrack Deploy — tag: ${BUILD_TAG}"
echo "════════════════════════════════════════════════════"

# ── 1. Run tests ─────────────────────────────────────────────────────────
echo ""
echo "🧪 Step 1: Running unit tests..."
python3 -m pytest tests/ -v --tb=short
echo "✅ Tests passed"

# ── 2. Build Docker image ────────────────────────────────────────────────
echo ""
echo "🐳 Step 2: Building Docker image..."
docker build \
  -t "${IMAGE_NAME}:${BUILD_TAG}" \
  -t "${IMAGE_NAME}:latest" \
  .
echo "✅ Image built: ${IMAGE_NAME}:${BUILD_TAG}"

# ── 3. Trivy scan ───────────────────────────────────────────────────────
echo ""
echo "🔍 Step 3: Scanning image with Trivy..."
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 0 \
  --no-progress \
  "${IMAGE_NAME}:${BUILD_TAG}"
echo "✅ Trivy scan complete"

# ── 4. Push to DockerHub ────────────────────────────────────────────────
echo ""
echo "📤 Step 4: Pushing to DockerHub..."
docker push "${IMAGE_NAME}:${BUILD_TAG}"
docker push "${IMAGE_NAME}:latest"
echo "✅ Pushed to DockerHub"

# ── 5. Ensure Minikube is running ───────────────────────────────────────
echo ""
echo "☸️  Step 5: Checking Minikube..."
if ! minikube status | grep -q "Running"; then
  echo "Starting Minikube..."
  minikube start --driver=docker --memory=4096 --cpus=2
fi
echo "✅ Minikube running"

# ── 6. Enable metrics-server for HPA ───────────────────────────────────
minikube addons enable metrics-server 2>/dev/null || true

# ── 7. Apply Kubernetes manifests ──────────────────────────────────────
echo ""
echo "☸️  Step 6: Deploying to Kubernetes..."
sed "s|IMAGE_TAG|${BUILD_TAG}|g" k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

echo "⏳ Waiting for rollout..."
kubectl rollout status deployment/fintrack --timeout=120s
echo "✅ Deployment complete"

# ── 8. Smoke test ────────────────────────────────────────────────────────
echo ""
echo "💨 Step 7: Smoke test..."
APP_URL=$(minikube service fintrack --url)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/health")
if [ "$STATUS" = "200" ]; then
  echo "✅ App is healthy!"
else
  echo "❌ Health check failed (HTTP ${STATUS})"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  ✅  FinTrack deployed successfully!"
echo ""
echo "  🌐 App URL:        ${APP_URL}"
echo "  📊 Metrics:        ${APP_URL}/metrics"
echo "  🔍 Pods:           kubectl get pods"
echo "  📈 HPA status:     kubectl get hpa"
echo "════════════════════════════════════════════════════"
