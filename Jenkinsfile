pipeline {
    agent any

    environment {
        DOCKERHUB_USER    = credentials('dockerhub-username')
        DOCKERHUB_PASS    = credentials('dockerhub-password')
        IMAGE_NAME        = "${DOCKERHUB_USER}/fintrack"
        IMAGE_TAG         = "${BUILD_NUMBER}"
        SONAR_TOKEN       = credentials('sonarqube-token')
        SONAR_HOST        = 'http://localhost:9000'
        KUBECONFIG        = credentials('kubeconfig')
    }

    stages {

        // ── 1. Checkout ──────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/selva-bharathi6603/fintrack-devops.git'
                echo " Code checked out — Build #${BUILD_NUMBER}"
            }
        }

        // ── 2. Install dependencies ──────────────────────────────────────
        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r app/requirements.txt
                '''
            }
        }

        // ── 3. Run Unit Tests ────────────────────────────────────────────
        stage('Unit Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    python -m pytest tests/ -v --tb=short \
                        --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        // ── 4. SonarQube Analysis ────────────────────────────────────────
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                            -Dsonar.projectKey=fintrack \
                            -Dsonar.projectName="FinTrack" \
                            -Dsonar.projectVersion=${BUILD_NUMBER} \
                            -Dsonar.sources=app \
                            -Dsonar.tests=tests \
                            -Dsonar.python.version=3 \
                            -Dsonar.host.url=${SONAR_HOST} \
                            -Dsonar.login=${SONAR_TOKEN}
                    '''
                }
            }
        }

        // ── 5. Quality Gate ──────────────────────────────────────────────
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ── 6. Docker Build ──────────────────────────────────────────────
        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:latest \
                        .
                    echo " Image built: ${IMAGE_NAME}:${IMAGE_TAG}"
                '''
            }
        }

        // ── 7. Trivy Security Scan ───────────────────────────────────────
        stage('Trivy Scan') {
            steps {
                sh '''
                    trivy image \
                        --exit-code 1 \
                        --severity HIGH,CRITICAL \
                        --no-progress \
                        --format table \
                        ${IMAGE_NAME}:${IMAGE_TAG} || true

                    trivy image \
                        --format json \
                        --output trivy-report.json \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true
                }
            }
        }

        // ── 8. Push to DockerHub ─────────────────────────────────────────
        stage('Push to DockerHub') {
            steps {
                sh '''
                    echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                    echo " Pushed ${IMAGE_NAME}:${IMAGE_TAG} to DockerHub"
                '''
            }
        }

        // ── 9. Deploy to Kubernetes ──────────────────────────────────────
        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    export KUBECONFIG=${KUBECONFIG}

                    # Substitute image tag in deployment manifest
                    sed -i "s|IMAGE_TAG|${IMAGE_TAG}|g" k8s/deployment.yaml

                    kubectl apply -f k8s/configmap.yaml
                    kubectl apply -f k8s/secret.yaml
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl apply -f k8s/hpa.yaml

                    # Wait for rollout to complete
                    kubectl rollout status deployment/fintrack --timeout=120s
                    echo " Deployment successful"
                '''
            }
        }

        // ── 10. Smoke Test ───────────────────────────────────────────────
        stage('Smoke Test') {
            steps {
                sh '''
                    APP_URL=$(minikube service fintrack --url)
                    STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/health)
                    if [ "$STATUS" != "200" ]; then
                        echo " Smoke test failed — HTTP ${STATUS}"
                        exit 1
                    fi
                    echo " Smoke test passed — App is healthy at ${APP_URL}"
                '''
            }
        }
    }

    post {
        success {
            echo " Pipeline completed successfully — Build #${BUILD_NUMBER}"
        }
        failure {
            echo " Pipeline failed — Build #${BUILD_NUMBER}"
        }
        always {
            sh 'docker logout || true'
            cleanWs()
        }
    }
}
