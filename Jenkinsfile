pipeline {
    agent {
        label 'gcp-agent'
    }

    environment {
        PROJECT_ID     = 'andrei-innowise-tests-120826'
        REGION         = 'europe-north1'
        REGISTRY_NAME  = 'gke-repo'
        IMAGE_NAME     = 'apod-api'
        MANIFEST_PATH  = 'k8s-manifests/apod/apod-deployment.yaml'
        ARGOCD_SERVER  = 'argocd-server.argocd.svc.cluster.local:80'
        ARGOCD_TOKEN   = credentials('argocd-jenkins-token')
        GITHUB_CREDS   = credentials('github-jenkins-token')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                echo "Pulling latest code from Git..."
                checkout scm
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                container('build-tools') {
                    sh """#!/bin/bash
                        set -e
                        
                        # Generate unique image tag using build number and short git hash
                        GIT_COMMIT_SHORT=\$(git rev-parse --short HEAD)
                        IMAGE_TAG="v1.0.\${BUILD_NUMBER}-\${GIT_COMMIT_SHORT}"
                        FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}/${IMAGE_NAME}:\${IMAGE_TAG}"

                        echo "===> Configuring GCP Artifact Registry Docker Auth..."
                        gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

                        echo "===> Building Docker image: \${FULL_IMAGE}"
                        docker build -t \${FULL_IMAGE} app/apod-api/

                        echo "===> Pushing Docker image to GCP Artifact Registry..."
                        docker push \${FULL_IMAGE}

                        # Save tag for next stage
                        echo "\${FULL_IMAGE}" > .image_tag
                    """
                }
            }
        }

        stage('Update GitOps Manifest & Write-Back') {
            steps {
                container('build-tools') {
                    sh """#!/bin/bash
                        set -e
                        FULL_IMAGE=\$(cat .image_tag)

                        echo "===> Updating deployment manifest: ${MANIFEST_PATH}"
                        
                        # Replace image reference in deployment manifest
                        sed -i "s|image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}/${IMAGE_NAME}:.*|image: \${FULL_IMAGE}|g" ${MANIFEST_PATH}

                        echo "===> Checking Git diff..."
                        git diff ${MANIFEST_PATH}

                        # Configure Git identity for Jenkins
                        git config user.email "jenkins-ci@innowise.com"
                        git config user.name "Jenkins CI Bot"

                        # Authenticate and push change back to GitHub
                        echo "===> Committing updated image tag back to Git..."
                        git add ${MANIFEST_PATH}
                        
                        # [skip ci] prevents GitHub Webhook from re-triggering this pipeline recursively
                        git commit -m "chore(ci): auto-update apod-api image to \${FULL_IMAGE} [skip ci]" || echo "No changes to commit"
                        
                        git push https://${GITHUB_CREDS_USR}:${GITHUB_CREDS_PSW}@github.com/onneyami/gcp-terraform-task-2.git HEAD:main
                    """
                }
            }
        }

        stage('Trigger ArgoCD Sync') {
            steps {
                script {
                    sh """#!/bin/bash
                        echo "===> Triggering ArgoCD sync cycle for all applications..."
                        
                        APP_LIST_FILE=\$(mktemp)
                        HTTP_STATUS=\$(curl -s -o "\$APP_LIST_FILE" -w "%{http_code}" -X GET \\
                          -H "Authorization: Bearer \${ARGOCD_TOKEN}" \\
                          "http://${env.ARGOCD_SERVER}/api/v1/applications")

                        APP_NAMES=\$(grep -o '"metadata":{[^}]*}' "\$APP_LIST_FILE" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sort -u)

                        for APP in \$APP_NAMES; do
                            echo "--> Triggering sync for application: \$APP"
                            curl -s -X POST \\
                              -H "Authorization: Bearer \${ARGOCD_TOKEN}" \\
                              -H "Content-Type: application/json" \\
                              "http://${env.ARGOCD_SERVER}/api/v1/applications/\$APP/sync" \\
                              -d '{"prune": true}' > /dev/null
                        done
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ Build, push, Git write-back, and ArgoCD sync completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed during build or sync phase."
        }
    }
}