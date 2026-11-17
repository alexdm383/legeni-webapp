// Pipeline CI/CD Legeni WebApp – job Multibranch
//  - toutes les branches / PR : qualité en parallèle -> build -> scan Trivy
//  - main uniquement         : push -> staging -> validation humaine -> production
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    environment {
        DOCKERHUB_ID = 'alexdm38'
        IMAGE        = "${DOCKERHUB_ID}/legeni-webapp"
        TEST_IMAGE   = "legeni-test:ci-${BUILD_NUMBER}"
        DEPLOYER     = "legeni-deployer:ci-${BUILD_NUMBER}"
    }

    stages {
        stage('Préparation') {
            steps {
                script {
                    env.APP_VERSION = readFile('VERSION').trim()
                    env.TAG = "${env.APP_VERSION}-${env.BUILD_NUMBER}"   // ex. 1.0.0-12, jamais "latest"
                }
                echo "Branche ${env.BRANCH_NAME} - image ${env.IMAGE}:${env.TAG}"
            }
        }

        stage('Qualité') {
            parallel {
                stage('Tests + couverture + flake8') {
                    steps {
                        sh '''
                            docker build --target test -t $TEST_IMAGE .
                            rm -rf reports
                            cid=$(docker create $TEST_IMAGE)
                            docker cp $cid:/reports ./reports
                            docker rm $cid
                        '''
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                            archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/**'
                            script {
                                // Plugins "Coverage" et "Warnings Next Generation" : utilisés s'ils sont installés
                                try {
                                    recordCoverage(tools: [[parser: 'COBERTURA', pattern: 'reports/coverage.xml']])
                                } catch (Throwable t) { echo 'Plugin Coverage absent : rapport archivé seulement' }
                                try {
                                    recordIssues(tools: [flake8(pattern: 'reports/flake8.txt')])
                                } catch (Throwable t) { echo 'Plugin Warnings NG absent : rapport archivé seulement' }
                            }
                        }
                    }
                }
                stage('Hadolint') {
                    steps {
                        sh 'docker run --rm -i hadolint/hadolint:v2.12.0 < Dockerfile'
                    }
                }
                stage('Syntaxe Ansible') {
                    steps {
                        sh 'docker build -f ci/deployer.Dockerfile -t $DEPLOYER ansible'
                        // deploy.yml charge vault.yml (chiffré) : la vérification a besoin du mot de passe Vault
                        withCredentials([string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                            sh '''
                                docker run --rm -e VAULT_PASS $DEPLOYER sh -c \
                                  'printf "%s" "$VAULT_PASS" > /tmp/vp && ansible-playbook --syntax-check deploy.yml -e target_env=staging --vault-password-file /tmp/vp'
                                docker run --rm $DEPLOYER ansible-playbook --syntax-check provision.yml
                            '''
                        }
                    }
                }
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --target runtime --pull --build-arg APP_VERSION=$TAG -t $IMAGE:$TAG .'
            }
        }

        stage('Scan Trivy') {
            steps {
                // Échoue s'il reste une vulnérabilité CRITICAL corrigeable
                sh '''
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        -v trivy-cache:/root/.cache/ aquasec/trivy:0.57.1 \
                        image --severity CRITICAL --ignore-unfixed --exit-code 1 $IMAGE:$TAG
                '''
            }
        }

        stage('Push Docker Hub') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_TOKEN')]) {
                    sh '''
                        echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
                        docker push $IMAGE:$TAG
                        docker logout
                    '''
                }
            }
        }

        stage('Déploiement staging') {
            when { branch 'main' }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KCFG'),
                                 string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                    sh 'ci/run-deploy.sh staging $TAG'
                }
            }
        }

        stage('Validation production') {
            when { branch 'main' }
            steps {
                timeout(time: 2, unit: 'HOURS') {
                    input message: "Staging OK en ${env.TAG}. Déployer en production ?", ok: 'Déployer en prod'
                }
            }
        }

        stage('Déploiement production') {
            when { branch 'main' }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KCFG'),
                                 string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                    sh 'ci/run-deploy.sh prod $TAG'
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline OK : ${env.IMAGE}:${env.TAG}"
        }
        failure {
            script {
                // Notification Discord si le credential "discord-webhook" (Secret text) existe
                try {
                    withCredentials([string(credentialsId: 'discord-webhook', variable: 'HOOK')]) {
                        sh '''curl -s -H "Content-Type: application/json" \
                              -d "{\\"content\\": \\"❌ Échec $JOB_NAME #$BUILD_NUMBER : $BUILD_URL\\"}" "$HOOK"'''
                    }
                } catch (Throwable t) {
                    echo 'Échec du pipeline (pas de webhook Discord configuré)'
                }
            }
        }
        always {
            sh 'docker rmi -f $TEST_IMAGE $DEPLOYER >/dev/null 2>&1 || true'
        }
    }
}