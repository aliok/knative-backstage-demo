# Knative Backstage Demo

This is a demo of:
- Knative Event Mesh Backstage plugin: Showing Knative Eventing resources in Backstage
- Knative Function templates: Generating Knative Function code in Backstage

A video of the demo is available at https://www.youtube.com/watch?v=4h1j1v8KrY0

## Quickstart

See [quickstart](quickstart) for using a pre-built container image for this demo.

## Installation

Install Knative Eventing and Serving:

```bash
./000-infra/01-kn-serving.sh
./000-infra/02-kn-eventing.sh
```

Create broker, services and other resources:

```bash
kubectl apply -f ./100-manifest/100-broker.yaml
kubectl apply -f ./100-manifest/151-paymentreceived-event-type.yaml
kubectl apply -f ./100-manifest/152-paymentprocessed-event-type.yaml
kubectl apply -f ./100-manifest/153-frauddetected-event-type.yaml
kubectl apply -f ./100-manifest/200-payment-processor.yaml
kubectl apply -f ./100-manifest/210-fraud-detector.yaml
kubectl apply -f ./100-manifest/220-fraud-logger.yaml
kubectl apply -f ./100-manifest/280-all-events-logger.yaml
kubectl apply -f ./100-manifest/290-payment-event-generator.yaml
```

Install the Backstage plugin backend:

```bash
# points to https://github.com/knative-extensions/backstage-plugins/pull/85
# find from https://console.cloud.google.com/storage/browser/knative-nightly/backstage-plugins/previous;tab=objects?pageState=(%22StorageObjectListTable%22:(%22f%22:%22%255B%255D%22,%22s%22:%5B(%22i%22:%22displayName%22,%22s%22:%221%22)%5D))&authuser=0&prefix=&forceOnObjectsSortingFiltering=true
kubectl apply -f https://storage.googleapis.com/knative-nightly/backstage-plugins/previous/v20240919-00059a3/eventmesh.yaml
```

## Starting up

You need a service account that you will give to the Backstage backend. This will be passed in every request to the backend from the plugin
and it will be used to access the Kubernetes API:
```bash
# 1. create a new service account in your namespace
kubectl -n default create serviceaccount backstage-admin
# 2. create a clusterrolebinding
kubectl create clusterrolebinding backstage-admin --clusterrole=cluster-admin --serviceaccount=default:backstage-admin
# 3. create a secret for the service account
kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: backstage-admin
      namespace: default
      annotations:
        kubernetes.io/service-account.name: backstage-admin
    type: kubernetes.io/service-account-token
EOF
```

Set up some environment variables:
```bash
export KUBE_API_SERVER_URL=$(kubectl config view --minify --output jsonpath="{.clusters[*].cluster.server}") # e.g. "https://192.168.2.151:16443"
# get the SA token
export KUBE_SA_TOKEN=$(kubectl -n default get secret backstage-admin -o jsonpath='{.data.token}' | base64 --decode)

# run a sanity check with the token
curl -k -H "Authorization: Bearer $KUBE_SA_TOKEN" -X GET "${KUBE_API_SERVER_URL}/api/v1/nodes" | json_pp
```

Port-forward the backend service:
```bash
kubectl port-forward -n knative-eventing svc/eventmesh-backend 8080:8080
```

Run a sanity check:
```bash
curl -v -H "Authorization: Bearer $KUBE_SA_TOKEN" http://localhost:8080/
> {"eventTypes":[...],"brokers":[...]}
```

Set up more environment variables:
```bash
export KNATIVE_EVENT_MESH_BACKEND="http://localhost:8080"
export KNATIVE_EVENT_MESH_TOKEN=$KUBE_SA_TOKEN
```

For the templates, you will need a GitHub token to be able to push the generated code to a repository. 
You can create a token from the GitHub settings page and give it the `repo` scope.

Alternatively, for local development, you can use a personal token created by the `gh` CLI.

```bash
export GITHUB_TOKEN=<your-token>
# or
export GITHUB_TOKEN=$(gh auth token)
```


Start Backstage:
```bash

cd backstage
yarn install
yarn dev

# open http://localhost:3000/
```


## Cleanup

```bash
kubectl delete -f ./100-manifest/290-payment-event-generator.yaml
kubectl delete -f ./100-manifest/280-all-events-logger.yaml
kubectl delete -f ./100-manifest/220-fraud-logger.yaml
kubectl delete -f ./100-manifest/210-fraud-detector.yaml
kubectl delete -f ./100-manifest/200-payment-processor.yaml
kubectl delete -f ./100-manifest/153-frauddetected-event-type.yaml
kubectl delete -f ./100-manifest/152-paymentprocessed-event-type.yaml
kubectl delete -f ./100-manifest/151-paymentreceived-event-type.yaml
kubectl delete -f ./100-manifest/100-broker.yaml
```

TODO:
- Resources for various cases:
  -  Random service that's not connected to anything

## Building demo images

There are 2 images:

- [event-generator](apps/event-generator): A simple app that generates events and sends them to a sink (for instance, to a broker).
- [generic-service](apps/generic-service): A simple app that receives events and logs them. It can also send a reply event (optional).

### event-generator

```bash
  # go to the app directory
  cd apps/event-generator
  
  # install dependencies
  npm install
  
  # run locally
  K_SINK="https://example.com" node index.js
  
  # Output
  > Sending event: {"id":"d33cc086-bb7a-4e8d-a90e-d11789a35e6d","time":"2024-02-02T10:49:08.053Z","type":"com.example.event","source":"event-generator","specversion":"1.0","data":{"message":"Hello 1"}} to https://example.com
  
  # build docker image
  docker build . -t aliok/event-generator --platform=linux/amd64
  
  # run docker image locally
  docker run --name=test-event-generator --detach=false --rm --env K_SINK="https://example.com" aliok/event-generator:latest

  # publish
  docker push aliok/event-generator
```

### generic-service

```bash
  # go to the app directory
  cd apps/generic-service
  
  # install dependencies
  npm install
  
  # run locally
  REPLY_TYPE="test-reply" REPLY_PERCENTAGE="50" node index.js
  
  # Send a test event
  curl -i 'http://localhost:8080/'                      \
  -H 'ce-time: 2023-09-26T12:35:14.372688+00:00'      \
  -H 'ce-type: com.mycompany.paymentreceived'           \
  -H 'ce-source: test'   \
  -H 'ce-id: a9254f41-4d32-45d2-8293-e90d96876de1'    \
  -H 'ce-specversion: 1.0'                            \
  -H 'accept: */*'                                    \
  -H 'accept-encoding: gzip, deflate'                 \
  -H 'content-type: '                                 \
  -d $'{"foo": "bar"}'
  
  # Output (reply)
  {"id":"a9254f41-4d32-45d2-8293-e90d96876de1","time":"2023-09-26T12:35:14.372Z","type":"com.mycompany.paymentreceived","source":"test","specversion":"1.0","data_base64":"eyJmb28iOiAiYmFyIn0=","data":{"type":"Buffer","data":[123,34,102,111,111,34,58,32,34,98,97,114,34,125]}} 

  # See the logs
  =======================
    Request headers:
    {
      host: 'localhost:8080',
      'user-agent': 'curl/8.4.0',
      'ce-time': '2023-09-26T12:35:14.372688+00:00',
      'ce-type': 'com.mycompany.paymentreceived',
      'ce-source': 'test',
      'ce-id': 'a9254f41-4d32-45d2-8293-e90d96876de1',
      'ce-specversion': '1.0',
      accept: '*/*',
      'accept-encoding': 'gzip, deflate',
      'content-length': '14'
    }
    
    Request body - to string:
    {"foo": "bar"}
    =======================
    
    Received event:
    {"id":"a9254f41-4d32-45d2-8293-e90d96876de1","time":"2023-09-26T12:35:14.372Z","type":"com.mycompany.paymentreceived","source":"test","specversion":"1.0","data_base64":"eyJmb28iOiAiYmFyIn0="}
    =======================
  
  # build docker image
  docker build . -t aliok/generic-service --platform=linux/amd64
  
  # run docker image locally
  docker run --name=test-generic-service --detach=false --rm -p 8080:8080 -e REPLY_TYPE="test-reply" aliok/generic-service:latest

  # publish
  docker push aliok/generic-service
```

## Running the quickstart container image

See [quickstart](quickstart) for using a pre-built container image for this demo.

## Building the quick start container image

```bash
docker build . -f quickstart/Dockerfile -t aliok/knative-backstage-demo --platform=linux/amd64 --progress=plain
docker push aliok/knative-backstage-demo
```
