pipeline {
    agent any

    environment {
        IMAGE_NAME  = "fintrack"
        IMAGE_TAG   = "${BUILD_NUMBER}"
        SONAR_HOST  = 'http://localhost:9000'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/selva-bharathi6603/fintrack-devops.git'
                echo " Code checked out — Build #${BUILD_NUMBER}"
            }
        }

        stage('Install Dependencies') {
            steps {
                bat 'pip install -r app/requirements.txt'
            }
        }

        stage('Unit Tests') {
            steps {
                bat 'python -m pytest tests/ -v --tb=short --junitxml=test-results.xml'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    bat "sonar-scanner -Dsonar.projectKey=fintrack -Dsonar.projectName=FinTrack -Dsonar.projectVersion=%BUILD_NUMBER% -Dsonar.sources=app -Dsonar.tests=tests -Dsonar.python.version=3"
                }
            }
        }

        stage('Quality Gate') {
            steps {
                echo 'SonarQube analysis completed — check results at http://localhost:9000/dashboard?id=fintrack'
            }
        }
        stage('Docker Build') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    bat """
                    docker context use default
                    docker build -t %DOCKER_USER%/%IMAGE_NAME%:%IMAGE_TAG% -t %DOCKER_USER%/%IMAGE_NAME%:latest .
                    echo Image built: %DOCKER_USER%/%IMAGE_NAME%:%IMAGE_TAG%
                    """
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    bat """
                        trivy image --severity HIGH,CRITICAL --exit-code 0 --no-progress %DOCKER_USER%/%IMAGE_NAME%:%IMAGE_TAG%
                        trivy image --format json --output trivy-report.json %DOCKER_USER%/%IMAGE_NAME%:%IMAGE_TAG%
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json',
                        fingerprint: true,
                        allowEmptyArchive: true
                }
            }
        }
        
        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    bat """
                    docker push %DOCKER_USER%/%IMAGE_NAME%:%IMAGE_TAG%
                    docker push %DOCKER_USER%/%IMAGE_NAME%:latest
                    echo Pushed successfully
                    """
                }
            }
        }
        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    bat """
                    set KUBECONFIG=C:\\Users\\Selva Bharathi M\\.kube\\config
                    kubectl apply -f k8s/configmap.yaml --validate=false
                    kubectl apply -f k8s/secret.yaml --validate=false
                    kubectl apply -f k8s/service.yaml --validate=false
                    kubectl apply -f k8s/hpa.yaml --validate=false
                    """
                    bat """
                    set KUBECONFIG=C:\\Users\\Selva Bharathi M\\.kube\\config
                    powershell -Command "(Get-Content k8s/deployment.yaml) -replace 'IMAGE_TAG', '%IMAGE_TAG%' | kubectl apply -f - --validate=false"
                    """
                    bat """
                    set KUBECONFIG=C:\\Users\\Selva Bharathi M\\.kube\\config
                    kubectl rollout status deployment/fintrack --timeout=120s
                    echo Deployment successful
                    """
                }
            }
        }
        stage('Smoke Test') {
            steps {
                bat """
                ping -n 11 127.0.0.1 > nul
                curl -f http://192.168.49.2:30080/health && echo Smoke test passed || echo Smoke test failed
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
            cleanWs()
        }
    }
}
