# Knative Backstage Demo

This demo app is a container image built from https://github.com/aliok/knative-backstage-demo

A video of the demo is available at https://www.youtube.com/watch?v=4h1j1v8KrY0

## Prerequisites

You need a Kubernetes cluster with Knative Eventing and Serving deployed.

See https://knative.dev/docs/install/ for installing Knative.


## Running the quickstart container image

This quickstart container creates some resources in the cluster and then it starts a Backstage instance.
To create the resources, it needs a lot of permissions. Run the following commands to give the necessary permissions:

```shell
cat <<EOF | kubectl apply -f -
# create a new namespace called knative-backstage-demo
apiVersion: v1
kind: Namespace
metadata:
  name: knative-backstage-demo
---
# create a new cluster role that allows the demo container to create things like brokers, triggers, and events
# the demo container will also create the event mesh controller, which needs lots of permissions.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: knative-backstage-demo
rules:
  - apiGroups:
      - "*"
    resources:
      - "*"
    verbs:
      - get
      - list
      - create
      - update
      - delete
      - patch
      - watch
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: knative-backstage-demo
  namespace: knative-backstage-demo
  labels:
    app.kubernetes.io/version: devel
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: knative-backstage-demo
subjects:
  - kind: ServiceAccount
    name: knative-backstage-demo
    namespace: knative-backstage-demo
roleRef:
  kind: ClusterRole
  name: knative-backstage-demo
  apiGroup: rbac.authorization.k8s.io
EOF
```

For the templates, you will need a GitHub token to be able to push the generated code to a repository.
You can create a token from the GitHub settings page and give it the `repo` scope.

Alternatively, for local development, you can use a personal token created by the `gh` CLI.

```bash
export GITHUB_TOKEN=<your-token>
# or
export GITHUB_TOKEN=$(gh auth token)
```

Create the demo app:

```shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: knative-backstage-demo
  namespace: knative-backstage-demo
  labels:
    app: knative-backstage-demo
spec:
  serviceAccountName: knative-backstage-demo
  containers:
  - image: aliok/knative-backstage-demo
    name: knative-backstage-demo
    ports:
    - containerPort: 3000
    - containerPort: 7007
    env:
    - name: GITHUB_TOKEN
      value: $GITHUB_TOKEN
---
apiVersion: v1
kind: Service
metadata:
  name: knative-backstage-demo
  namespace: knative-backstage-demo
  labels:
    app: knative-backstage-demo
spec:
  ports:
    - name: ui
      port: 3000
      targetPort: 3000
    - name: api
      port: 7007
      targetPort: 7007  
  selector:
    app: knative-backstage-demo
EOF
```

Expose the Backstage web UI and the API server:

```shell
kubectl port-forward -n knative-backstage-demo svc/knative-backstage-demo 3000:3000
kubectl port-forward -n knative-backstage-demo svc/knative-backstage-demo 7007:7007
```

The port forwarding commands above might fail, if the Backstage server is not ready yet.

In that case, you need to wait a bit and then try again.

To make sure, you can check the logs of the `knative-backstage-demo` pod:

```shell
> kubectl logs -n knative-backstage-demo knative-backstage-demo
# ... wait until
# [0] <i> [webpack-dev-server] Project is running at:
# [0] <i> [webpack-dev-server] Loopback: http://localhost:3000/, http://[::1]:3000/
```

Open the Backstage web UI:

```shell
# open http://localhost:3000/
```

## Cleanup

```shell
# svc and the demo pod
kubectl delete svc -n knative-backstage-demo knative-backstage-demo
kubectl delete pod -n knative-backstage-demo knative-backstage-demo
# RBAC and SA for the demo container
kubectl delete clusterrolebinding knative-backstage-demo
kubectl delete clusterrole knative-backstage-demo
kubectl delete serviceaccount -n knative-backstage-demo knative-backstage-demo
# RBAC and SA for the Backstage instance
kubectl delete clusterrolebinding backstage-admin
kubectl delete clusterrole backstage-admin
kubectl delete serviceaccount -n knative-backstage-demo backstage-admin
# The namespace
kubectl delete namespace knative-backstage-demo
```

## Building the image

```shell
docker build . -f quickstart/Dockerfile -t aliok/knative-backstage-demo --platform=linux/amd64
docker push aliok/knative-backstage-demo
```
