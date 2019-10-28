/*
 * This is a vanilla Jenkins pipeline that relies on the Jenkins kubernetes plugin to dynamically provision agents for
 * the build containers.
 *
 * The individual containers are defined in the `jenkins-pod-template.yaml` and the containers are referenced by name
 * in the `container()` blocks. The underlying pod definition expects certain kube Secrets and ConfigMap objects to
 * have been created in order for the Pod to run. See `jenkins-pod-template.yaml` for more information.
 *
 * The cloudName variable is set dynamically based on the existance/value of env.CLOUD_NAME which allows this pipeline
 * to run in both Kubernetes and OpenShift environments.
 */

def buildAgentName(String jobName, String buildNumber) {
    if (jobName.length() > 23) {
        jobName = jobName.substring(0, 23);
    }

    return "agent.${jobName}.${buildNumber}".replace('_', '-').replace('/', '-').replace('-.', '.');
}

def buildLabel = buildAgentName(env.JOB_NAME, env.BUILD_NUMBER);
def cloudName = env.CLOUD_NAME == "openshift" ? "openshift" : "kubernetes"
def workingDir = env.CLOUD_NAME == "openshift" ? "/home/jenkins" : "/home/jenkins/agent"
podTemplate(
   label: buildLabel,
   cloud: cloudName,
   yaml: """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
    - name: java
      image: openjdk:11
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      env:
        - name: HOME
          value: ${workingDir}
    - name: ibmcloud
      image: docker.io/garagecatalyst/ibmcloud-dev:1.0.7
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      envFrom:
        - configMapRef:
            name: ibmcloud-config
        - secretRef:
            name: ibmcloud-apikey
      env:
        - name: CHART_NAME
          value: template-project-docs
        - name: CHART_ROOT
          value: chart
        - name: TMP_DIR
          value: .tmp
        - name: HOME
          value: /home/devops
        - name: BUILD_NUMBER
          value: ${env.BUILD_NUMBER}
"""
) {
    node(buildLabel) {
        container(name: 'java', shell: '/bin/bash') {
            checkout scm
            stage('Setup') {
                sh '''#!/bin/bash
                    set -x
                    # Export project name, version, and build number to ./env-config
                    ./gradlew -q printName | xargs -I {} echo "IMAGE_NAME={}" > ./env-config
                    ./gradlew -q printVersion | xargs -I {} echo "IMAGE_VERSION={}" >> ./env-config
                    echo "BUILD_NUMBER=${BUILD_NUMBER}" >> ./env-config
                '''
            }
            stage('Build') {
                sh '''#!/bin/bash
                    set -x
                    ./gradlew asciidoctor
                '''
            }
        }
        container(name: 'ibmcloud', shell: '/bin/bash') {
            stage('Verify environment') {
                sh '''#!/bin/bash
                    set -x
                    
                    whoami
                    
                    . ./env-config

                    if [[ -z "${APIKEY}" ]]; then
                      echo "APIKEY is required"
                      exit 1
                    fi
                    
                    if [[ -z "${RESOURCE_GROUP}" ]]; then
                      echo "RESOURCE_GROUP is required"
                      exit 1
                    fi
                    
                    if [[ -z "${REGION}" ]]; then
                      echo "REGION is required"
                      exit 1
                    fi
                    
                    if [[ -z "${REGISTRY_NAMESPACE}" ]]; then
                      echo "REGISTRY_NAMESPACE is required"
                      exit 1
                    fi
                    
                    if [[ -z "${REGISTRY_URL}" ]]; then
                      echo "REGISTRY_URL is required"
                      exit 1
                    fi
                    
                    if [[ -z "${IMAGE_NAME}" ]]; then
                      echo "IMAGE_NAME is required"
                      exit 1
                    fi
                    
                    if [[ -z "${IMAGE_VERSION}" ]]; then
                      echo "IMAGE_VERSION is required"
                      exit 1
                    fi
                '''
            }
            stage('Build image') {
                sh '''#!/bin/bash
                    set -x
                    
                    . ./env-config

                    echo "Checking registry namespace: ${REGISTRY_NAMESPACE}"
                    NS=$( ibmcloud cr namespaces | grep ${REGISTRY_NAMESPACE} ||: )
                    if [[ -z "${NS}" ]]; then
                        echo -e "Registry namespace ${REGISTRY_NAMESPACE} not found, creating it."
                        ibmcloud cr namespace-add ${REGISTRY_NAMESPACE}
                    else
                        echo -e "Registry namespace ${REGISTRY_NAMESPACE} found."
                    fi

                    echo -e "Existing images in registry"
                    ibmcloud cr images --restrict "${REGISTRY_NAMESPACE}/${IMAGE_NAME}"
                    
                    echo -e "=========================================================================================="
                    echo -e "BUILDING CONTAINER IMAGE: ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION}"
                    set -x
                    ibmcloud cr build -t ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION} .
                    if [[ -n "${BUILD_NUMBER}" ]]; then
                        echo -e "BUILDING CONTAINER IMAGE: ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION}-${BUILD_NUMBER}"
                        ibmcloud cr image-tag ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION} ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION}-${BUILD_NUMBER}
                    fi
                    
                    echo -e "Available images in registry"
                    ibmcloud cr images --restrict ${REGISTRY_NAMESPACE}/${IMAGE_NAME}
                '''
            }
            stage('Deploy to DEV env') {
                sh '''#!/bin/bash
                    set -x

                    . ./env-config
                    
                    ENVIRONMENT_NAME=dev

                    CHART_PATH="${CHART_ROOT}/${CHART_NAME}"

                    echo "KUBECONFIG=${KUBECONFIG}"

                    RELEASE_NAME="${IMAGE_NAME}"
                    echo "RELEASE_NAME: $RELEASE_NAME"

                    if [[ -n "${BUILD_NUMBER}" ]]; then
                      IMAGE_VERSION="${IMAGE_VERSION}-${BUILD_NUMBER}"
                    fi
                    
                    echo "INITIALIZING helm with client-only (no Tiller)"
                    helm init --client-only 1> /dev/null 2> /dev/null
                    
                    echo "CHECKING CHART (lint)"
                    helm lint ${CHART_PATH}
                    
                    IMAGE_REPOSITORY="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}"
                    PIPELINE_IMAGE_URL="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION}"

                    # Using 'upgrade --install" for rolling updates. Note that subsequent updates will occur in the same namespace the release is currently deployed in, ignoring the explicit--namespace argument".
                    helm template ${CHART_PATH} \
                        --name ${RELEASE_NAME} \
                        --namespace ${ENVIRONMENT_NAME} \
                        --set nameOverride=docs \
                        --set image.repository=${IMAGE_REPOSITORY} \
                        --set image.tag=${IMAGE_VERSION} \
                        --set ingress.tlsSecretName="${TLS_SECRET_NAME}" \
                        --set ingress.namespaceInHost=false \
                        --set ingress.subdomain="${INGRESS_SUBDOMAIN}" > ./release.yaml
                    
                    echo -e "Generated release yaml for: ${CLUSTER_NAME}/${ENVIRONMENT_NAME}."
                    cat ./release.yaml
                    
                    echo -e "Deploying into: ${CLUSTER_NAME}/${ENVIRONMENT_NAME}."
                    kubectl apply -n ${ENVIRONMENT_NAME} -f ./release.yaml

                    # ${SCRIPT_ROOT}/deploy-checkstatus.sh ${ENVIRONMENT_NAME} ${IMAGE_NAME} ${IMAGE_REPOSITORY} ${IMAGE_VERSION}
                '''
            }
            stage('Health Check') {
                sh '''#!/bin/bash
                    . ./env-config
                    
                    ENVIRONMENT_NAME=dev

                    INGRESS_NAME="${IMAGE_NAME}-docs"
                    INGRESS_HOST=$(kubectl get ingress/${INGRESS_NAME} --namespace ${ENVIRONMENT_NAME} --output=jsonpath='{ .spec.rules[0].host }')
                    PORT='80'

                    # sleep for 10 seconds to allow enough time for the server to start
                    sleep 30

                    if [ $(curl -sL -w "%{http_code}\\n" "http://${INGRESS_HOST}:${PORT}" -o /dev/null --connect-timeout 3 --max-time 5 --retry 3 --retry-max-time 30) == "200" ]; then
                        echo "Successfully reached health endpoint: http://${INGRESS_HOST}:${PORT}"
                    echo "====================================================================="
                        else
                    echo "Could not reach health endpoint: http://${INGRESS_HOST}:${PORT}"
                        exit 1;
                    fi;

                '''
            }
        }
    }
}

