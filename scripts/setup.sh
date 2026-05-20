#!/usr/bin/env bash
# setup.sh — Install all DevOps tools on Ubuntu/Debian
# Run: chmod +x scripts/setup.sh && ./scripts/setup.sh

set -euo pipefail
echo "🚀 FinTrack DevOps Setup — installing all tools..."

# ── Helper ────────────────────────────────────────────────────────────────
check() { command -v "$1" &>/dev/null; }

# ── Docker ────────────────────────────────────────────────────────────────
if ! check docker; then
  echo "📦 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "✅ Docker installed"
else
  echo "✅ Docker already installed"
fi

# ── Minikube ──────────────────────────────────────────────────────────────
if ! check minikube; then
  echo "📦 Installing Minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
  echo "✅ Minikube installed"
else
  echo "✅ Minikube already installed"
fi

# ── kubectl ───────────────────────────────────────────────────────────────
if ! check kubectl; then
  echo "📦 Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
  echo "✅ kubectl installed"
else
  echo "✅ kubectl already installed"
fi

# ── Trivy ─────────────────────────────────────────────────────────────────
if ! check trivy; then
  echo "📦 Installing Trivy..."
  sudo apt-get install -y wget apt-transport-https gnupg lsb-release
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
  echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list
  sudo apt-get update && sudo apt-get install -y trivy
  echo "✅ Trivy installed"
else
  echo "✅ Trivy already installed"
fi

# ── Helm ──────────────────────────────────────────────────────────────────
if ! check helm; then
  echo "📦 Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "✅ Helm installed"
else
  echo "✅ Helm already installed"
fi

# ── SonarQube Scanner ─────────────────────────────────────────────────────
if ! check sonar-scanner; then
  echo "📦 Installing SonarQube Scanner..."
  SONAR_VER="6.1.0.4477"
  wget -q "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_VER}-linux.zip"
  unzip -q "sonar-scanner-cli-${SONAR_VER}-linux.zip"
  sudo mv "sonar-scanner-${SONAR_VER}-linux" /opt/sonar-scanner
  sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
  rm "sonar-scanner-cli-${SONAR_VER}-linux.zip"
  echo "✅ SonarQube Scanner installed"
else
  echo "✅ SonarQube Scanner already installed"
fi

# ── Python deps ───────────────────────────────────────────────────────────
echo "📦 Installing Python dependencies..."
pip3 install --quiet -r app/requirements.txt
echo "✅ Python dependencies installed"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅  All tools installed successfully!"
echo ""
echo "  Next steps:"
echo "  1. Start Minikube:       minikube start"
echo "  2. Start tooling stack:  docker-compose up -d"
echo "  3. Deploy the app:       ./scripts/deploy.sh"
echo "  4. Open Jenkins:         http://localhost:8080"
echo "  5. Open SonarQube:       http://localhost:9000"
echo "  6. Open Grafana:         http://localhost:3000"
echo "════════════════════════════════════════════════════════"
