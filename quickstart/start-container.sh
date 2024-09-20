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
kubectl apply -n knative-eventing -f https://storage.googleapis.com/knative-nightly/backstage-plugins/previous/v20240208-408beed/eventmesh.yaml

echo "Switching to Backstage directory"
cd backstage

echo "Installing Backstage dependencies"
yarn install

export KNATIVE_EVENT_MESH_BACKEND="http://eventmesh-backend.knative-eventing.svc:8080"
echo "KNATIVE_EVENT_MESH_BACKEND: ${KNATIVE_EVENT_MESH_BACKEND}"

echo "Starting Backstage"
yarn dev
