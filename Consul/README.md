# Consul Service Discovery and <p> Kong for Kubernetes

Consul Service Discovery introduction

The following picture describes the Ingress Gateway, Ingress Controller and Service Mesh architecture.
![Architecture](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/architecture.png)


#  System Requirements

- A Kubernetes Cluster. This exercise was done on an AWS EKS Cluster. Both Consul Connect and Kong Enterprise support any Kubernetes distribution.
- kubectl
- Helm 3.x
- Consul CLI
- HTTPie and Curl.


#  Installation Process

## Step 1: Consul Installation

1. Add HashiCorp repo to your local Helm installation.

<pre>
helm repo add hashicorp https://helm.releases.hashicorp.com
</pre>

2. Use the following [YAML file](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/consul-values.yml) to install Consul. Notice we are setting synchronization between Kubernetes and Consul services.

<pre>
global:
  datacenter: dc1
  image: "consul:1.8.4"

# Expose the Consul UI through this LoadBalancer
ui:
  service:
    type: LoadBalancer

# Configure a Consul client on Kubernetes nodes. GRPC listener is required for Connect.
client:
  enabled: true
  grpc: true


# Minimal Consul configuration. Not suitable for production.
server:
  replicas: 1
  bootstrapExpect: 1
  disruptionBudget:
    enabled: true
    maxUnavailable: 0

# Sync Kubernetes and Consul services
syncCatalog:
  enabled: false
</pre>

3. Create a Namespace for Consul
<pre>kubectl create namespace hashicorp</pre>


4. Install Consul Connect

<pre>
helm install consul-connect -n hashicorp hashicorp/consul -f consul-values.yml
</pre>

5. Check the installation

<pre>
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                             READY   STATUS    RESTARTS   AGE
hashicorp     consul-connect-consul-ng48h      1/1     Running   0          69s
hashicorp     consul-connect-consul-server-0   1/1     Running   0          69s
kube-system   aws-node-4zshh                   1/1     Running   0          2m47s
kube-system   coredns-74df49b88b-8qqh6         1/1     Running   0          9m22s
kube-system   coredns-74df49b88b-9r9qq         1/1     Running   0          9m22s
kube-system   kube-proxy-gkp95                 1/1     Running   0          2m47s
</pre>

<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                           TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)                                                                   AGE
default       kubernetes                     ClusterIP      10.100.0.1       <none>                                                                   443/TCP                                                                   9m46s
hashicorp     consul-connect-consul-dns      ClusterIP      10.100.152.144   <none>                                                                   53/TCP,53/UDP                                                             83s
hashicorp     consul-connect-consul-server   ClusterIP      None             <none>                                                                   8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   83s
hashicorp     consul-connect-consul-ui       LoadBalancer   10.100.27.89     a45764982a377466888a55b42b6dd752-268952251.us-west-1.elb.amazonaws.com   80:30979/TCP                                                              83s
kube-system   kube-dns                       ClusterIP      10.100.0.10      <none>                                                                   53/UDP,53/TCP                                                             9m43s
</pre>

Check the Consul Connect services redirecting your browser to Consul UI:
![ConsulConnect](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/ConsulConnect.png)


## Step 2: Configure Consul DNS
<pre>
kubectl get service consul-connect-consul-dns -n hashicorp -o jsonpath='{.spec.clusterIP}'
10.100.152.144
</pre>

<pre>
kubectl edit configmap coredns -n kube-system
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    consul {
        errors
        cache 30
        forward . 10.100.152.144
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2020-06-19T13:42:16Z"
  managedFields:
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:data:
        .: {}
        f:Corefile: {}
    manager: kubeadm
    operation: Update
    time: "2020-06-19T13:42:16Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "178"
  selfLink: /api/v1/namespaces/kube-system/configmaps/coredns
  uid: 698c5d0c-998e-4aa4-9857-67958eeee25a
</pre>



## Step 3: Deploy Sample Microservice and Canary

Canary description

1. Deploy Sample Microservice

Use the following declarations to deploy the Sample Microservice, [Sample Deployment](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/deployment_benigno_v1.yaml) and [Sample Service](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/service_benigno.yaml)

After the deployment you should see the new Kubernetes Pods as well as the new Consul Services.
<pre>
kubectl apply -f deployment_benigno_v1.yaml
kubectl apply -f service_benigno.yaml
</pre>

2. Check the installation
<pre>
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                             READY   STATUS    RESTARTS   AGE
default       benigno-v1-fd4567d95-dbq8x       1/1     Running   0          24s
hashicorp     consul-connect-consul-ng48h      1/1     Running   0          5m39s
hashicorp     consul-connect-consul-server-0   1/1     Running   0          5m39s
kube-system   aws-node-4zshh                   1/1     Running   0          7m17s
kube-system   coredns-74df49b88b-8qqh6         1/1     Running   0          13m
kube-system   coredns-74df49b88b-9r9qq         1/1     Running   0          13m
kube-system   kube-proxy-gkp95                 1/1     Running   0          7m17s
</pre>

<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                           TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)                                                                   AGE
default       benigno-v1                     ClusterIP      10.100.114.214   <none>                                                                   5000/TCP                                                                  30s
default       kubernetes                     ClusterIP      10.100.0.1       <none>                                                                   443/TCP                                                                   14m
hashicorp     consul-connect-consul-dns      ClusterIP      10.100.152.144   <none>                                                                   53/TCP,53/UDP                                                             5m46s
hashicorp     consul-connect-consul-server   ClusterIP      None             <none>                                                                   8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   5m46s
hashicorp     consul-connect-consul-ui       LoadBalancer   10.100.27.89     a45764982a377466888a55b42b6dd752-268952251.us-west-1.elb.amazonaws.com   80:30979/TCP                                                              5m46s
kube-system   kube-dns                       ClusterIP      10.100.0.10      <none>                                                                   53/UDP,53/TCP                                                             14m
</pre>

3. Check the Microservice

Open a terminal and expose the Benigno Service:
<pre>
kubectl port-forward service/benigno-v1 5000:5000
</pre>

On another terminal send a request to it:
<pre>
$ http :5000
HTTP/1.0 200 OK
Content-Length: 20
Content-Type: text/html; charset=utf-8
Date: Tue, 06 Oct 2020 22:46:23 GMT
Server: Werkzeug/1.0.1 Python/3.8.3

Hello World, Benigno
</pre>



4. Deploy the Canary Release

Use the simliar declarations to deploy the Canary Release Microservice, [Canary Deployment](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/deployment_benigno_rc.yaml) and [Canary Service](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/service_benigno_rc.yaml)

<pre>
kubectl apply -f deployment_benigno_rc.yaml
kubectl apply -f service_benigno_rc.yaml
</pre>


## Step 4: Register the Consul Service for both Microservices releases

1. Get the Microservices Services ClusterIP addresses

Since, the two Microservices have been deployed, a new Consul Service, abstracting the two Microservices addresses, should be defined. The addresses can be obtained using the Consul APIs again:
<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                           TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)                                                                   AGE
default       benigno-v1                     ClusterIP      10.100.114.214   <none>                                                                   5000/TCP                                                                  3m49s
default       benigno-v2                     ClusterIP      10.100.239.33    <none>                                                                   5000/TCP                                                                  75s
default       kubernetes                     ClusterIP      10.100.0.1       <none>                                                                   443/TCP                                                                   17m
hashicorp     consul-connect-consul-dns      ClusterIP      10.100.152.144   <none>                                                                   53/TCP,53/UDP                                                             9m5s
hashicorp     consul-connect-consul-server   ClusterIP      None             <none>                                                                   8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   9m5s
hashicorp     consul-connect-consul-ui       LoadBalancer   10.100.27.89     a45764982a377466888a55b42b6dd752-268952251.us-west-1.elb.amazonaws.com   80:30979/TCP                                                              9m5s
kube-system   kube-dns                       ClusterIP      10.100.0.10      <none>                                                                   53/UDP,53/TCP                                                             17m
</pre>


2. Create the new Consul Service templates

Using these templates, [primary](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/ben0.json) and [secondary](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/ben1.json), create declarations for the Consul Service with the Microservices addresses as primary and secondary. Notice that the new Consul Service is named as <b>benigno1</b>. That's the name the consumers of the service should use. Moreover, the declarations are defining load balancing weights for primary and secondary IPs.

<pre>
ben0.json
{
  "ID": "ben0",
  "Name": "benigno1",
  "Tags": ["primary"],
  "Address": "10.100.114.214",
  "Port": 5000,
  "weights": {
    "passing": 80,
    "warning": 1
  }
}
</pre>

and

<pre>
ben1.json
{
  "ID": "ben1",
  "Name": "benigno1",
  "Tags": ["secondary"],
  "Address": "10.100.239.33",
  "Port": 5000,
  "weights": {
    "passing": 20,
    "warning": 1
  }
}
</pre>



3. Register the new Consul Service

Register the Consul Service using the Consul API:
<pre>
http put :8500/v1/agent/service/register < ben0.json
http put :8500/v1/agent/service/register < ben1.json
</pre>


Check the Service with:
<pre>
$ http :8500/v1/agent/health/service/name/benigno1
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 258
Content-Type: application/json
Date: Tue, 06 Oct 2020 23:05:20 GMT
Vary: Accept-Encoding
X-Consul-Reason: passing

[
    {
        "AggregatedStatus": "passing",
        "Checks": [],
        "Service": {
            "Address": "10.100.114.214",
            "EnableTagOverride": false,
            "ID": "ben0",
            "Meta": {},
            "Port": 5000,
            "Service": "benigno1",
            "TaggedAddresses": {
                "lan_ipv4": {
                    "Address": "10.100.114.214",
                    "Port": 5000
                },
                "wan_ipv4": {
                    "Address": "10.100.114.214",
                    "Port": 5000
                }
            },
            "Tags": [
                "primary"
            ],
            "Weights": {
                "Passing": 80,
                "Warning": 1
            }
        }
    },
    {
        "AggregatedStatus": "passing",
        "Checks": [],
        "Service": {
            "Address": "10.100.239.33",
            "EnableTagOverride": false,
            "ID": "ben1",
            "Meta": {},
            "Port": 5000,
            "Service": "benigno1",
            "TaggedAddresses": {
                "lan_ipv4": {
                    "Address": "10.100.239.33",
                    "Port": 5000
                },
                "wan_ipv4": {
                    "Address": "10.100.239.33",
                    "Port": 5000
                }
            },
            "Tags": [
                "secondary"
            ],
            "Weights": {
                "Passing": 20,
                "Warning": 1
            }
        }
    }
]
</pre>


4. Register the Kubernetes Service

The Kubernetes [service](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/externalservice_benigno.yaml) defines an internal reference for the Consul Service:

<pre>
kind: Service
apiVersion: v1
metadata:
  name: benigno1
spec:
  ports:
  - protocol: TCP
    port: 5000
  type: ExternalName
  externalName: benigno1.service.consul
</pre>

Use <b>kubectl</b> to apply it:
<pre>
kubectl apply -f benignoservice.yaml
</pre>


## Step 5: Kong for Kubernetes (K4K8S) Installation
1. Install Kong for Kubernetes

Add Kong Repository:
<pre>
helm repo add kong https://charts.konghq.com
</pre>

Create a Namespace:
<pre>
kubectl create namespace kong
</pre>

Install Kong for Kubernetes with <b>Helm</b>
<pre>
helm install kong kong/kong -n kong --set ingressController.installCRDs=false
</pre>

2. Check the installation

<pre>
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                             READY   STATUS    RESTARTS   AGE
default       benigno-v1-fd4567d95-dbq8x       1/1     Running   0          11m
default       benigno-v2-b977c867b-c7g8n       1/1     Running   0          8m38s
hashicorp     consul-connect-consul-ng48h      1/1     Running   0          16m
hashicorp     consul-connect-consul-server-0   1/1     Running   0          16m
kong          kong-kong-6f784b6686-56bmj       2/2     Running   0          18s
kube-system   aws-node-4zshh                   1/1     Running   0          18m
kube-system   coredns-74df49b88b-8qqh6         1/1     Running   0          24m
kube-system   coredns-74df49b88b-9r9qq         1/1     Running   0          24m
kube-system   kube-proxy-gkp95                 1/1     Running   0          18m
</pre>

<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                           TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)                                                                   AGE
default       benigno-v1                     ClusterIP      10.100.114.214   <none>                                                                   5000/TCP                                                                  24m
default       benigno-v2                     ClusterIP      10.100.239.33    <none>                                                                   5000/TCP                                                                  21m
default       benigno1                       ExternalName   <none>           benigno1.service.consul                                                  5000/TCP                                                                  19s
default       kubernetes                     ClusterIP      10.100.0.1       <none>                                                                   443/TCP                                                                   37m
hashicorp     consul-connect-consul-dns      ClusterIP      10.100.152.144   <none>                                                                   53/TCP,53/UDP                                                             29m
hashicorp     consul-connect-consul-server   ClusterIP      None             <none>                                                                   8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   29m
hashicorp     consul-connect-consul-ui       LoadBalancer   10.100.27.89     a45764982a377466888a55b42b6dd752-268952251.us-west-1.elb.amazonaws.com   80:30979/TCP                                                              29m
kong          kong-kong-proxy                LoadBalancer   10.100.251.2     aea3aec28f585467e95521be14cfb212-818134820.us-west-1.elb.amazonaws.com   80:32702/TCP,443:31347/TCP                                                13m
kube-system   kube-dns                       ClusterIP      10.100.0.10      <none>                                                                   53/UDP,53/TCP                                                             37m
</pre>


3. Check the Kong Proxy

Hit Kong Proxy through the Load Balancer provisioned by AWS:

<pre>
$ http aea3aec28f585467e95521be14cfb212-818134820.us-west-1.elb.amazonaws.com
HTTP/1.1 404 Not Found
Connection: keep-alive
Content-Length: 48
Content-Type: application/json; charset=utf-8
Date: Tue, 06 Oct 2020 22:58:34 GMT
Server: kong/2.1.4
X-Kong-Response-Latency: 0

{
    "message": "no Route matched with those values"
}
</pre>

The return message is coming from Kong for Kubernetes, saying there's no API defined yet.



4. Check Consul DNS

Open a terminal inside K4K8S pod to run check the <b>benigno1</b> naming resolution with a simple <nslookup> command:
<pre>
$ kubectl exec -ti kong-kong-6f784b6686-56bmj -n kong -- /bin/sh
Defaulting container name to ingress-controller.
Use 'kubectl describe pod/kong-kong-6f784b6686-56bmj -n kong' to see all of the containers in this pod.
/ $ nslookup benigno1.service.consul
Server:		10.100.0.10
Address:	10.100.0.10:53


Name:	benigno1.service.consul
Address: 10.100.239.33
Name:	benigno1.service.consul
Address: 10.100.114.214

/ $ exit
</pre>



## Step 6: Define Kong Ingress

1. Create an Ingress using this [declaration](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/benignoroute.yaml):
<pre>
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: benignoroute
  namespace: hashicorp
  annotations:
    kubernetes.io/ingress.class: kong
    konghq.com/strip-path: "true"
spec:
  rules:
  - http:
      paths:
        - path: /benignoroute
          backend:
            serviceName: benigno1
            servicePort: 5000
</pre>

Use <kubectl> to apply it:
<pre>
kubectl apply -f benignoroute.yaml
</pre>

2. Testing the Ingress
<pre>
$ http aea3aec28f585467e95521be14cfb212-818134820.us-west-1.elb.amazonaws.com/benignoroute
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 36
Content-Type: text/html; charset=utf-8
Date: Tue, 06 Oct 2020 23:09:55 GMT
Server: Werkzeug/1.0.1 Python/3.8.3
Via: kong/2.1.4
X-Kong-Proxy-Latency: 14
X-Kong-Upstream-Latency: 2

Hello World, Benigno, Canary Release
</pre>


Run a loop if you want to see the Canary in action

while [ 1 ]; do curl http://aea3aec28f585467e95521be14cfb212-818134820.us-west-1.elb.amazonaws.com/benignoroute; sleep 1; echo; done
