pipeline {
    agent any

    environment {
        DOCKERHUB_USER  = credentials('dockerhub-username')
        DOCKERHUB_PASS  = credentials('dockerhub-password')
        IMAGE_NAME      = "selva-bharathi6603/fintrack"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        SONAR_TOKEN     = credentials('sonarqube-token')
        SONAR_HOST      = 'http://localhost:9000'
    }

    stages {

        // ── 1. Checkout ──────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/selva-bharathi6603/fintrack-devops.git'
                echo "✅ Code checked out — Build #${BUILD_NUMBER}"
            }
        }

        // ── 2. Install Dependencies ──────────────────────────────────────
        stage('Install Dependencies') {
            steps {
                bat '''
                    pip install -r app/requirements.txt
                '''
            }
        }

        // ── 3. Unit Tests ────────────────────────────────────────────────
        stage('Unit Tests') {
            steps {
                bat '''
                    python -m pytest tests/ -v --tb=short --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results.xml'
                }
            }
        }

        // ── 4. SonarQube Analysis ────────────────────────────────────────────────
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    bat "sonar-scanner -Dsonar.projectKey=fintrack -Dsonar.projectName=FinTrack -Dsonar.projectVersion=%BUILD_NUMBER% -Dsonar.sources=app -Dsonar.tests=tests -Dsonar.python.version=3"
                }
            }
        }
        
        // ── 5. Quality Gate ──────────────────────────────────────────────────
        stage('Quality Gate') {
            steps {
                echo 'SonarQube analysis completed — check results at http://localhost:9000/dashboard?id=fintrack'
            }
        }

        // ── 6. Docker Build ──────────────────────────────────────────────
        stage('Docker Build') {
            steps {
                bat """
                    docker build -t %IMAGE_NAME%:%IMAGE_TAG% -t %IMAGE_NAME%:latest .
                    echo Image built: %IMAGE_NAME%:%IMAGE_TAG%
                """
            }
        }

        // ── 7. Trivy Scan ────────────────────────────────────────────────
        stage('Trivy Scan') {
            steps {
                bat """
                    trivy image --severity HIGH,CRITICAL --exit-code 0 --no-progress %IMAGE_NAME%:%IMAGE_TAG%
                    trivy image --format json --output trivy-report.json %IMAGE_NAME%:%IMAGE_TAG%
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true, allowEmptyArchive: true
                }
            }
        }

        // ── 8. Push to DockerHub ─────────────────────────────────────────
        stage('Push to DockerHub') {
            steps {
                bat """
                    echo %DOCKERHUB_PASS% | docker login -u %DOCKERHUB_USER% --password-stdin
                    docker push %IMAGE_NAME%:%IMAGE_TAG%
                    docker push %IMAGE_NAME%:latest
                    echo Pushed %IMAGE_NAME%:%IMAGE_TAG%
                """
            }
        }

        // ── 9. Deploy to Kubernetes ──────────────────────────────────────
        stage('Deploy to Kubernetes') {
            steps {
                bat """
                    kubectl apply -f k8s/configmap.yaml
                    kubectl apply -f k8s/secret.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl apply -f k8s/hpa.yaml
                """
                bat """
                    powershell -Command "(Get-Content k8s/deployment.yaml) -replace 'IMAGE_TAG', '%IMAGE_TAG%' | kubectl apply -f -"
                """
                bat """
                    kubectl rollout status deployment/fintrack --timeout=120s
                    echo Deployment successful
                """
            }
        }

        // ── 10. Smoke Test ───────────────────────────────────────────────
        stage('Smoke Test') {
            steps {
                bat """
                    powershell -Command "
                        \$url = 'http://localhost:30080/health'
                        \$status = (Invoke-WebRequest -Uri \$url -UseBasicParsing).StatusCode
                        if (\$status -eq 200) {
                            Write-Host 'Smoke test passed'
                        } else {
                            Write-Host 'Smoke test failed'
                            exit 1
                        }
                    "
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully — Build #${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline failed — Build #${BUILD_NUMBER}"
        }
        always {
            bat 'docker logout || exit 0'
            cleanWs()
        }
    }
}
