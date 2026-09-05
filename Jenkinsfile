pipeline {
    agent any

    environment {
        ARGOCD_SERVER = 'argocd-server.argocd.svc.cluster.local:80'
        ARGOCD_TOKEN  = credentials('argocd-jenkins-token')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout Manifests') {
            steps {
                echo "Pulling latest manifests from Git..."
                checkout scm
            }
        }

        stage('Trigger ArgoCD Sync for All Apps') {
            steps {
                script {
                    sh """#!/bin/bash
                        echo "Fetching list of all registered ArgoCD applications..."
                        
                        APP_LIST_FILE=\$(mktemp)
                        
                        HTTP_STATUS=\$(curl -s -o "\$APP_LIST_FILE" -w "%{http_code}" -X GET \\
                          -H "Authorization: Bearer \${ARGOCD_TOKEN}" \\
                          "http://${env.ARGOCD_SERVER}/api/v1/applications")

                        if [ "\$HTTP_STATUS" -ne 200 ]; then
                            echo "ERROR: Failed to fetch applications from ArgoCD (HTTP \$HTTP_STATUS)"
                            cat "\$APP_LIST_FILE"
                            exit 1
                        fi

                        # POSIX clean extraction of application metadata names
                        APP_NAMES=\$(grep -o '"metadata":{[^}]*}' "\$APP_LIST_FILE" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sort -u)

                        if [ -z "\$APP_NAMES" ]; then
                            echo "No applications found or failed to parse JSON."
                            cat "\$APP_LIST_FILE"
                            exit 1
                        fi

                        echo "Discovered applications to sync:"
                        echo "\$APP_NAMES"
                        echo "--------------------------------------------------"

                        for APP in \$APP_NAMES; do
                            echo "--> Triggering sync for application: \$APP"
                            
                            SYNC_RESPONSE_FILE=\$(mktemp)
                            
                            SYNC_STATUS=\$(curl -s -o "\$SYNC_RESPONSE_FILE" -w "%{http_code}" -X POST \\
                              -H "Authorization: Bearer \${ARGOCD_TOKEN}" \\
                              -H "Content-Type: application/json" \\
                              "http://${env.ARGOCD_SERVER}/api/v1/applications/\$APP/sync" \\
                              -d '{"prune": true}')

                            if [ "\$SYNC_STATUS" -eq 200 ]; then
                                echo "    [OK] Successfully triggered sync for \$APP"
                            else
                                echo "    [WARNING] Sync returned HTTP \$SYNC_STATUS for \$APP"
                                cat "\$SYNC_RESPONSE_FILE"
                                echo ""
                            fi
                        done
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Successfully triggered ArgoCD sync cycle for all applications!"
        }
        failure {
            echo "Failed to trigger ArgoCD sync cycle."
        }
    }
}