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
        GITHUB_CREDS   = credentials('github-jenkins-token')
        TARGET_BRANCH  = 'dev'
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
                        
                        BUILD_ID=\$(gcloud builds submit app/apod-api/ \\
                          --tag="\${FULL_IMAGE}" \\
                          --project="${PROJECT_ID}" \\
                          --async \\
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

        stage('Update GitOps Manifest & Write-Back to Dev Branch') {
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

                        echo "===> Fetching latest ${env.TARGET_BRANCH} branch..."
                        git fetch origin ${env.TARGET_BRANCH}
                        git checkout ${env.TARGET_BRANCH}

                        echo "===> Updating deployment manifest: ${MANIFEST_PATH}"
                        sed -i "s|image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REGISTRY_NAME}/${IMAGE_NAME}:.*|image: \${FULL_IMAGE}|g" ${MANIFEST_PATH}

                        git config user.email "jenkins-ci@innowise.com"
                        git config user.name "Jenkins CI Bot"

                        git add ${MANIFEST_PATH}
                        
                        git commit -m "chore(ci): auto-update apod-api image to \${FULL_IMAGE} [skip ci]" || echo "No changes to commit"
                        
                        echo "===> Pushing updated manifest to ${env.TARGET_BRANCH} branch..."
                        
                        CLEAN_GITHUB_TOKEN=\$(echo -n "\$GITHUB_CREDS_PSW" | tr -d '\\r\\n ')
                        
                        git push https://x-access-token:\${CLEAN_GITHUB_TOKEN}@github.com/onneyami/gcp-terraform-task-2.git HEAD:${env.TARGET_BRANCH}
                    """
                }
            }
        }

        stage('Trigger ArgoCD Sync') {
            when {
                environment name: 'SKIP_BUILD', value: 'false'
            }
            steps {
                container('build-tools') {
                    sh """#!/bin/bash
                        set -e
                        echo "===> Retrieving fresh ArgoCD token directly from Kubernetes Secret..."
                        
                        LIVE_TOKEN=\$(kubectl get secret jenkins-pipeline-secrets -n jenkins -o jsonpath='{.data.ARGOCD_TOKEN}' 2>/dev/null | base64 -d)

                        if [ -z "\$LIVE_TOKEN" ]; then
                            echo "❌ Failed to fetch ARGOCD_TOKEN from secret jenkins-pipeline-secrets in jenkins namespace."
                            exit 1
                        fi

                        echo "===> Querying all ArgoCD applications..."
                        RESPONSE_FILE=\$(mktemp)
                        HTTP_STATUS=\$(curl -s -o "\$RESPONSE_FILE" -w "%{http_code}" \\
                          -H "Authorization: Bearer \${LIVE_TOKEN}" \\
                          "http://${env.ARGOCD_SERVER}/api/v1/applications")

                        if [ "\${HTTP_STATUS}" -ne 200 ]; then
                            echo "❌ Failed to query ArgoCD API (HTTP \${HTTP_STATUS}):"
                            cat "\$RESPONSE_FILE"
                            exit 1
                        fi

                        APP_NAMES=\$(jq -r '.items[].metadata.name // empty' "\$RESPONSE_FILE")

                        if [ -z "\$APP_NAMES" ]; then
                            echo "⚠️ No applications found in ArgoCD response."
                            exit 0
                        fi

                        echo "Found applications:"
                        echo "\$APP_NAMES"
                        echo "----------------------------------------"

                        for APP in \$APP_NAMES; do
                            echo "--> Triggering sync for application: \$APP"
                            SYNC_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" -X POST \\
                              -H "Authorization: Bearer \${LIVE_TOKEN}" \\
                              -H "Content-Type: application/json" \\
                              "http://${env.ARGOCD_SERVER}/api/v1/applications/\$APP/sync" \\
                              -d '{"prune": true}')
                            echo "    Sync triggered for \$APP (HTTP \${SYNC_STATUS})"
                        done

                        echo "✅ Successfully triggered sync across all ArgoCD applications!"
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