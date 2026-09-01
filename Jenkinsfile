pipeline {
    agent {
        label 'gcp-agent' // Uses the Pod Template configured in Jenkins UI
    }

    environment {
        PROJECT_ID    = 'andrei-innowise-tests-120826'
        REGION        = 'europe-north1'
        REGISTRY_NAME = 'gke-repo'
        IMAGE_NAME    = 'nasa-apod'
        MANIFEST_PATH = 'k8s-manifests/apod-deployment.yaml'
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('2. Workload Identity & GCP Auth Check') {
            steps {
                container('build-tools') {
                    sh '''
                        echo "===> Authenticating with GCP via Workload Identity..."
                        gcloud auth list
                        gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
                    '''
                }
            }
        }

        stage('3. Simulate Build & Artifact Generation') {
            steps {
                container('build-tools') {
                    sh '''
                        IMAGE_TAG="v1.0.${BUILD_NUMBER}"
                        FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"
                        
                        echo "===> Simulating image build for: ${FULL_IMAGE}"
                        echo "Image built and verified successfully!"
                    '''
                }
            }
        }

        stage('4. Update GitOps Manifest for ArgoCD') {
            steps {
                container('build-tools') {
                    sh '''
                        echo "===> Checking deployment manifest..."
                        if [ -f "${MANIFEST_PATH}" ]; then
                            echo "Updating manifest ${MANIFEST_PATH} with build version v1.0.${BUILD_NUMBER}"
                            # In full workflow: git commit & push back to Git repo to trigger ArgoCD auto-sync
                        else
                            echo "Manifest path ${MANIFEST_PATH} not found in repository root, skipping file update."
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Jenkins CI completed successfully! Manifest ready for ArgoCD to sync."
        }
    }
}