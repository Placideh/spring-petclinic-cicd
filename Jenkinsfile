pipeline {
    agent any
    
    environment {
        // Docker configuration
        DOCKER_IMAGE = "211172/spring-petclinic"
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = "dockerhub-credentials"
        
        // Tool paths
        DOCKER_BIN = "/var/jenkins_home/bin/docker"
        KUBECTL_BIN = "/var/jenkins_home/bin/kubectl"
        
        // Maven configuration
        MAVEN_OPTS = "-Dmaven.repo.local=.m2/repository"

        JAVA_HOME = "/opt/java/openjdk"
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
    }
    
    stages {
        stage('1. Start') {
            steps {
                echo '==========================================='
                echo '🚀 CI/CD Pipeline Started'
                echo '==========================================='
                echo "Build Number: ${BUILD_NUMBER}"
                echo "Job Name: ${JOB_NAME}"
                echo "Workspace: ${WORKSPACE}"
                echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                echo '==========================================='
                sh '''
                    echo "=== Java Version ==="
                    java -version
                    echo "=== Maven Version ==="
                    ./mvnw -version
                '''
            }
        }
        
        stage('2. Build') {
            steps {
                echo '========== Stage 2: Build Application =========='
                script {
                    sh """
                        echo "Compiling Spring Boot application with Maven..."
                        ./mvnw clean install -DskipTests -Dcheckstyle.skip=true -Denforcer.skip=true
                        echo "✅ Build completed successfully"
                    """
                }
            }
        }
        
        stage('3. Test') {
            parallel {
                stage('3a. Unit Tests') {
                    steps {
                        echo '========== Running Unit Tests =========='
                        script {
                            sh """
                                echo "Running unit tests..."
                                ./mvnw test -Dtest=*Test -Dcheckstyle.skip=true -Denforcer.skip=true
                                echo "✅ Unit tests completed"
                            """
                        }
                    }
                }
                
                stage('3b. Integration Tests') {
                    steps {
                        echo '========== Running Integration Tests =========='
                        script {
                            sh """
                                echo "Running integration tests..."
                                ./mvnw verify -Dit.test=*IT -Dcheckstyle.skip=true -Denforcer.skip=true
                                echo "✅ Integration tests completed"
                            """
                        }
                    }
                }
            }
        }
        
        stage('4. Static Analysis') {
            parallel {
                stage('4a. Dependency Check (SCA)') {
                    steps {
                        echo '========== Dependency Check =========='
                        script {
                            sh """
                                echo "Running OWASP Dependency Check..."
                                ./mvnw org.owasp:dependency-check-maven:check || true
                                echo "✅ Dependency check completed"
                            """
                        }
                    }
                }
                
                stage('4b. Generate SBOM') {
                    steps {
                        echo '========== Generating SBOM =========='
                        script {
                            sh """
                                echo "Generating Software Bill of Materials..."
                                ./mvnw org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom || true
                                echo "✅ SBOM generated"
                            """
                        }
                    }
                }
                
                stage('4c. SonarQube Analysis') {
                    steps {
                        echo '========== SonarQube Analysis =========='
                        script {
                            sh """
                                echo "SonarQube analysis skipped (requires SonarQube server)"
                                echo "In production, would run: mvn sonar:sonar"
                                echo "✅ Static analysis stage completed"
                            """
                        }
                    }
                }
            }
        }
        
        stage('5. Package') {
            steps {
                echo '========== Stage 5: Package Application =========='
                script {
                    sh """
                        echo "Packaging application as JAR..."
                        ./mvnw package -DskipTests -Dcheckstyle.skip=true -Denforcer.skip=true
                        echo "Listing generated artifacts:"
                        ls -lh target/*.jar
                        echo "✅ Application packaged successfully"
                    """
                }
            }
        }
        
        stage('6. Docker Build & Push') {
            stages {
                stage('6a. Build Docker Image') {
                    steps {
                        echo '========== Building Docker Image =========='
                        script {
                            sh """
                                echo "Building Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                                ${DOCKER_BIN} build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                                ${DOCKER_BIN} tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                                echo "✅ Docker image built successfully"
                            """
                        }
                    }
                }
                
                stage('6b. Push to Docker Hub') {
                    steps {
                        echo '========== Pushing to Docker Hub =========='
                        script {
                            withCredentials([usernamePassword(
                                credentialsId: "${DOCKER_CREDENTIALS_ID}",
                                usernameVariable: 'DOCKER_USER',
                                passwordVariable: 'DOCKER_PASS'
                            )]) {
                                sh """
                                    echo "Logging into Docker Hub..."
                                    echo \${DOCKER_PASS} | ${DOCKER_BIN} login -u \${DOCKER_USER} --password-stdin
                                    
                                    echo "Pushing image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                                    ${DOCKER_BIN} push ${DOCKER_IMAGE}:${DOCKER_TAG}
                                    
                                    echo "Pushing image: ${DOCKER_IMAGE}:latest"
                                    ${DOCKER_BIN} push ${DOCKER_IMAGE}:latest
                                    
                                    echo "✅ Images pushed to Docker Hub successfully"
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage('7. Docker Image Scans') {
            parallel {
                stage('7a. Image Linting') {
                    steps {
                        echo '========== Docker Image Linting =========='
                        script {
                            sh """
                                echo "Linting Dockerfile..."
                                ${DOCKER_BIN} run --rm -i hadolint/hadolint < Dockerfile || true
                                echo "✅ Dockerfile linting completed"
                            """
                        }
                    }
                }
                
                stage('7b. Security Scan') {
                    steps {
                        echo '========== Security Scanning =========='
                        script {
                            sh """
                                echo "Running Trivy security scan..."
                                ${DOCKER_BIN} run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                                    aquasec/trivy:latest image --severity HIGH,CRITICAL \\
                                    ${DOCKER_IMAGE}:${DOCKER_TAG} || true
                                echo "✅ Security scan completed"
                            """
                        }
                    }
                }
            }
        }
        
        stage('8. Deploy to Kubernetes') {
            steps {
                echo '========== Stage 8: Deploy to Kubernetes =========='
                script {
                    sh """
                        echo "Updating Kubernetes deployment..."
                        
                        # Ensure namespace exists
                        ${KUBECTL_BIN} create namespace petclinic-prod --dry-run=client -o yaml | ${KUBECTL_BIN} apply -f -
                        
                        # Update image tag in deployment
                        sed -i 's|image: 211172/.*petclinic.*:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g' k8s/deployment.yaml
                        
                        # Show what we're deploying
                        echo "--- Deployment Configuration ---"
                        grep -A 3 "image:" k8s/deployment.yaml
                        
                        # Delete old pods to force clean restart
                        echo "Cleaning up old pods..."
                        ${KUBECTL_BIN} delete pods -n petclinic-prod -l app=petclinic --grace-period=0 --force || true
                        
                        # Wait for old pods to terminate
                        sleep 10
                        
                        # Apply Kubernetes manifests
                        echo "Applying Kubernetes manifests..."
                        ${KUBECTL_BIN} apply -f k8s/deployment.yaml
                        
                        # Give deployment time to start
                        echo "Waiting for deployment to register..."
                        sleep 15
                        
                        # Show deployment status
                        echo "--- Deployment Status ---"
                        ${KUBECTL_BIN} get deployment petclinic -n petclinic-prod
                        
                        # Show pod status
                        echo "--- Pod Status ---"
                        ${KUBECTL_BIN} get pods -n petclinic-prod -l app=petclinic -o wide
                        
                        # Show service
                        echo "--- Service Status ---"
                        ${KUBECTL_BIN} get svc -n petclinic-prod petclinic
                        
                        # Get application URL
                        NODE_PORT=\$(${KUBECTL_BIN} get svc petclinic -n petclinic-prod -o jsonpath='{.spec.ports[0].nodePort}')
                        NODE_IP=\$(hostname -I | awk '{print \$1}')
                        
                        echo "═══════════════════════════════════════"
                        echo "✅ Application URL: http://\${NODE_IP}:\${NODE_PORT}"
                        echo "═══════════════════════════════════════"
                        echo ""
                        echo "Note: Pods may still be starting. Check status with:"
                        echo "kubectl get pods -n petclinic-prod -l app=petclinic"
                        echo ""
                        echo "✅ Deployment manifests applied successfully"
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo '========== Pipeline Cleanup =========='
            script {
                // Logout from Docker
                sh "${DOCKER_BIN} logout || true"
                
                // Clean up dangling images
                sh """
                    echo "Cleaning up dangling Docker images..."
                    ${DOCKER_BIN} image prune -f || true
                    echo "Cleanup completed"
                """
            }
        }
        
        success {
            echo """
            ═══════════════════════════════════════════════════════════════
            ✅✅✅ PIPELINE COMPLETED SUCCESSFULLY ✅✅✅
            ═══════════════════════════════════════════════════════════════
            
            Build: #${BUILD_NUMBER}
            Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}
            
            Application deployment initiated!
            Check pod status: kubectl get pods -n petclinic-prod
            
            ═══════════════════════════════════════════════════════════════
            """
        }
        
        failure {
            echo """
            ═══════════════════════════════════════════════════════════════
            ❌❌❌ PIPELINE FAILED ❌❌❌
            ═══════════════════════════════════════════════════════════════
            """
            echo "Check console output above for detailed error messages"
            echo "Review the failed stage and fix the issues before retrying"
            echo """
            ═══════════════════════════════════════════════════════════════
            """
        }
    }
}


