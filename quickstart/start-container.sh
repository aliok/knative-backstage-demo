#!/usr/bin/env bash

export KUBE_API_SERVER_URL=https://kubernetes.default.svc

# Path to ServiceAccount token
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount

# Read this Pod's namespace
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)

# Read the ServiceAccount bearer token
export KUBE_SA_TOKEN=$(cat ${SERVICEACCOUNT}/token)

# Reference the internal certificate authority (CA)
CACERT=${SERVICEACCOUNT}/ca.crt

echo "Checking Kube API Server access"
# Explore the API with KUBE_SA_TOKEN
curl --cacert ${CACERT} --header "Authorization: Bearer ${KUBE_SA_TOKEN}" -X GET ${KUBE_API_SERVER_URL}/api

echo "Creating sample resources"
kubectl apply -n ${NAMESPACE} -f ./100-manifest/100-broker.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/151-paymentreceived-event-type.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/152-paymentprocessed-event-type.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/153-frauddetected-event-type.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/200-payment-processor.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/210-fraud-detector.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/220-fraud-logger.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/280-all-events-logger.yaml
kubectl apply -n ${NAMESPACE} -f ./100-manifest/290-payment-event-generator.yaml

echo "Creating Knative event mesh plugin backend"
kubectl apply -n knative-eventing -f https://storage.googleapis.com/knative-nightly/backstage-plugins/previous/v20240919-00059a3/eventmesh.yaml

echo "Creating Knative event mesh plugin secret for getting a token"
kubectl -n knative-backstage-demo create serviceaccount backstage-admin
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backstage-admin
rules:
  # permissions for eventtypes, brokers and triggers
  - apiGroups:
      - "eventing.knative.dev"
    resources:
      - brokers
      - eventtypes
      - triggers
    verbs:
      - get
      - list
      - watch
  # permissions to get subscribers for triggers
  # as subscribers can be any resource, we need to give access to all resources
  # we fetch subscribers one by one, we only need `get` verb
  - apiGroups:
      - "*"
    resources:
      - "*"
    verbs:
      - get
EOF
kubectl create clusterrolebinding backstage-admin --clusterrole=backstage-admin --serviceaccount=knative-backstage-demo:backstage-admin
kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: backstage-admin
      namespace: knative-backstage-demo
      annotations:
        kubernetes.io/service-account.name: backstage-admin
    type: kubernetes.io/service-account-token
EOF
export KNATIVE_EVENT_MESH_TOKEN=$(kubectl -n knative-backstage-demo get secret backstage-admin -o jsonpath='{.data.token}' | base64 -d)

export KNATIVE_EVENT_MESH_BACKEND="http://eventmesh-backend.knative-eventing.svc:8080"
echo "KNATIVE_EVENT_MESH_BACKEND: ${KNATIVE_EVENT_MESH_BACKEND}"

# run a sanity check with the token
echo "Checking the Knative event mesh plugin backend"
curl -k -H "Authorization: Bearer $KNATIVE_EVENT_MESH_TOKEN" -X GET "${KNATIVE_EVENT_MESH_BACKEND}"

echo "Switching to Backstage directory"
cd backstage

echo "Installing Backstage dependencies"
yarn install

echo "Starting Backstage"
yarn dev
