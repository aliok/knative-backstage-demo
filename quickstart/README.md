# Knative Backstage Demo

This demo app is a container image built from https://github.com/aliok/knative-backstage-demo

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

Open the Backstage web UI:

```shell
open http://localhost:3000/
```

## Cleanup

```shell
kubectl delete namespace knative-backstage-demo
kubectl delete clusterrolebinding knative-backstage-demo
kubectl delete clusterrole knative-backstage-demo
```
