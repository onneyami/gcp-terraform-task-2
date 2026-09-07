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
        stage('Evaluate Execution') {
            steps {
                script {
                    container('build-tools') {
                        sh "git config --global --add safe.directory '*'"
                        def commitMsg = sh(script: "git log -1 --pretty=%B", returnStdout: true).trim()
                        echo "Last commit message: ${commitMsg}"

                        if (commitMsg.contains('[skip ci]') || commitMsg.contains('Jenkins CI Bot')) {
                            env.SKIP_BUILD = 'true'
                            echo "===> [skip ci] detected! Setting SKIP_BUILD=true"
                        } else {
                            env.SKIP_BUILD = 'false'
                        }
                    }
                }
            }
        }

        stage('Build & Push Docker Image') {
            when {
                environment name: 'SKIP_BUILD', value: 'false'
            }
            steps {
                container('build-tools') {
                    sh """#!/bin/bash
                        set -e
                        git config --global --add safe.directory '*'

                        GIT_COMMIT_SHORT=\$(git rev-parse --short HEAD)
                        IMAGE_TAG="v1.0.\${BUILD_NUMBER}-\${GIT_COMMIT_SHORT}"
                        FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}/${IMAGE_NAME}:\${IMAGE_TAG}"

                        echo "===> Submitting asynchronous container build to Cloud Build: \${FULL_IMAGE}"
                        
                        BUILD_ID=\$(gcloud builds submit app/apod-api/ \
                          --tag="\${FULL_IMAGE}" \
                          --project="${PROJECT_ID}" \
                          --async \
                          --format="value(id)")

                        echo "===> Build submitted with ID: \${BUILD_ID}. Waiting for completion..."

                        while true; do
                            STATUS=\$(gcloud builds describe \${BUILD_ID} --project="${PROJECT_ID}" --format="value(status)")
                            echo "Current build status: \${STATUS}"
                            
                            if [ "\${STATUS}" = "SUCCESS" ]; then
                                echo "✅ Build completed successfully!"
                                break
                            elif [ "\${STATUS}" = "FAILURE" ] || [ "\${STATUS}" = "INTERNAL_ERROR" ] || [ "\${STATUS}" = "TIMEOUT" ]; then
                                echo "❌ Build failed with status: \${STATUS}"
                                exit 1
                            fi
                            sleep 10
                        done

                        echo "\${FULL_IMAGE}" > .image_tag
                    """
                }
            }
        }

        stage('Update GitOps Manifest & Write-Back') {
            when {
                environment name: 'SKIP_BUILD', value: 'false'
            }
            steps {
                container('build-tools') {
                    sh """#!/bin/bash
                        set -e
                        git config --global --add safe.directory '*'
                        
                        if [ ! -f .image_tag ]; then
                            echo "No image tag found. Skipping write-back."
                            exit 0
                        fi

                        FULL_IMAGE=\$(cat .image_tag)

                        echo "===> Updating deployment manifest: ${MANIFEST_PATH}"
                        sed -i "s|image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}/${IMAGE_NAME}:.*|image: \${FULL_IMAGE}|g" ${MANIFEST_PATH}

                        git config user.email "jenkins-ci@innowise.com"
                        git config user.name "Jenkins CI Bot"

                        git add ${MANIFEST_PATH}
                        
                        git commit -m "chore(ci): auto-update apod-api image to \${FULL_IMAGE} [skip ci]" || echo "No changes to commit"
                        
                        git push https://${GITHUB_CREDS_USR}:${GITHUB_CREDS_PSW}@github.com/onneyami/gcp-terraform-task-2.git HEAD:main
                    """
                }
            }
        }

        stage('Trigger ArgoCD Sync') {
            when {
                environment name: 'SKIP_BUILD', value: 'false'
            }
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
        always {
            echo "Pipeline evaluation complete."
        }
    }
}