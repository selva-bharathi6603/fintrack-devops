# FinTrack — DevOps Portfolio Project

> A Personal Finance Dashboard built with Python Flask and deployed via a full
> CI/CD pipeline using Jenkins, SonarQube, Trivy, Docker, DockerHub, and
> Kubernetes — all running locally, no cloud required.

---

## Tech Stack

| Layer | Tool |
|---|---|
| Application | Python, Flask, HTML, CSS |
| Version Control | Git, GitHub |
| CI/CD | Jenkins (Declarative Pipeline) |
| Code Quality | SonarQube |
| Security Scan | Trivy |
| Containerisation | Docker, DockerHub |
| Orchestration | Kubernetes (Minikube) |
| Monitoring | Prometheus, Grafana |
| Scripting | Bash |

---

## Project Structure

```
fintrack/
├── app/
│   ├── app.py                  # Flask app with /metrics endpoint
│   ├── templates/index.html    # Finance dashboard UI
│   ├── static/css/style.css    # Styles
│   └── requirements.txt
├── tests/
│   └── test_app.py             # Pytest unit tests (8 tests)
├── k8s/
│   ├── deployment.yaml         # 2 replicas, liveness + readiness probes
│   ├── service.yaml            # NodePort on 30080
│   ├── configmap.yaml          # Non-sensitive config
│   ├── secret.yaml             # Base64-encoded secrets
│   └── hpa.yaml                # Auto-scale 2→6 pods on CPU 60%
├── monitoring/
│   ├── prometheus.yml          # Scrape config for fintrack + jenkins
│   ├── prometheus-values.yaml  # Helm values for Prometheus
│   └── grafana-dashboard.json  # Import this into Grafana
├── scripts/
│   ├── setup.sh                # Install all tools (Ubuntu/Debian)
│   └── deploy.sh               # Manual build → scan → deploy
├── Dockerfile                  # Multi-stage build (builder + production)
├── Jenkinsfile                 # 10-stage declarative pipeline
├── docker-compose.yml          # Jenkins + SonarQube + Prometheus + Grafana
└── sonar-project.properties    # SonarQube project config
```

---

## Quick Start

### Prerequisites
- Ubuntu 20.04+ (or WSL2 on Windows)
- 8 GB RAM recommended
- Docker installed

### Step 1 — Clone and install tools

```bash
git clone https://github.com/YOUR_USERNAME/fintrack.git
cd fintrack
chmod +x scripts/setup.sh scripts/deploy.sh
./scripts/setup.sh
```

### Step 2 — Start the tooling stack

```bash
docker-compose up -d
```

| Service | URL | Credentials |
|---|---|---|
| Jenkins | http://localhost:8080 | setup wizard |
| SonarQube | http://localhost:9000 | admin / admin |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin |

### Step 3 — Configure Jenkins

1. Open http://localhost:8080
2. Install plugins: Git, Pipeline, SonarQube Scanner, Docker Pipeline, Kubernetes CLI
3. Add credentials:
   - `dockerhub-username` — DockerHub username (Secret text)
   - `dockerhub-password` — DockerHub password (Secret text)
   - `sonarqube-token` — SonarQube token (Secret text)
   - `kubeconfig` — contents of `~/.kube/config` (Secret file)
4. Configure SonarQube server at `Manage Jenkins → Configure System`
5. Create a Pipeline job pointing to this repo's Jenkinsfile

### Step 4 — Configure SonarQube

1. Open http://localhost:9000 (admin/admin)
2. Create project with key `fintrack`
3. Generate a token and add it to Jenkins as `sonarqube-token`

### Step 5 — Start Minikube

```bash
minikube start --driver=docker --memory=4096 --cpus=2
minikube addons enable metrics-server
```

### Step 6 — Push to GitHub and trigger the pipeline

```bash
git add .
git commit -m "feat: initial fintrack deployment"
git push origin main
```

The Jenkins webhook fires automatically. Watch the pipeline at http://localhost:8080.

### Step 7 — Access the app

```bash
minikube service fintrack --url
# Opens: http://192.168.49.2:30080
```

### Step 8 — Import Grafana dashboard

1. Open http://localhost:3000
2. Add Prometheus data source: `http://prometheus:9090`
3. Import `monitoring/grafana-dashboard.json`

---

## CI/CD Pipeline Stages

```
Checkout → Install deps → Unit Tests → SonarQube → Quality Gate
  → Docker Build → Trivy Scan → Push DockerHub → Deploy K8s → Smoke Test
```

Each stage either passes or fails the build. SonarQube quality gate blocks
promotion if code quality is below threshold.

---

## Kubernetes Resources

```bash
kubectl get all
kubectl get hpa
kubectl top pods

# Watch pods scale under load
kubectl run load --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://fintrack/; done"
kubectl get hpa -w
```

---

## Monitoring

The Flask app exposes Prometheus metrics at `/metrics`:

- `flask_http_request_total` — total requests by method + status
- `flask_http_request_duration_seconds` — latency histogram
- `flask_http_request_exceptions_total` — unhandled exceptions
- `fintrack_app_info` — app version gauge

Grafana panels:
- Request rate (req/sec)
- p95 response latency
- HTTP error rate (4xx/5xx)
- Active requests

---

## Resume Bullet Points

- Designed a 10-stage Jenkins CI/CD pipeline with GitHub webhook integration,
  automated unit testing (pytest), SonarQube quality gates, Trivy image
  vulnerability scanning, and zero-downtime rolling deployments to Kubernetes
- Containerized a Python Flask application using a multi-stage Docker build
  reducing image size by 60%; published versioned images to DockerHub
- Deployed to a local Kubernetes cluster (Minikube) with Deployment, Service,
  ConfigMap, Secret, and HPA resources enabling auto-scaling from 2 to 6 pods
  based on CPU utilization
- Instrumented the application with Prometheus metrics and built Grafana
  dashboards tracking request throughput, p95 latency, and error rate

---

## License

MIT
