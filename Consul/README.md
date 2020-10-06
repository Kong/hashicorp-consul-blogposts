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


## Step 4: Configure Consul DNS
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



## Step 2: Deploy Sample Microservice and Canary

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


## Step 3: Register the Consul Service for both Microservices releases

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

Using these templates, [primary](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/ben0.json) and [secondary](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/ben1.json), create declarations for the Consul Service with the Microservices addresses as primary and secondary.


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
Date: Tue, 06 Oct 2020 22:52:13 GMT
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

The Kubernetes [service](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/benignoservice.yaml) defines an internal reference for the Consul Service:

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
NAMESPACE     NAME                           TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)                                                                   AGE
default       benigno-v1                     ClusterIP      10.100.114.214   <none>                                                                   5000/TCP                                                                  11m
default       benigno-v2                     ClusterIP      10.100.239.33    <none>                                                                   5000/TCP                                                                  8m42s
default       kubernetes                     ClusterIP      10.100.0.1       <none>                                                                   443/TCP                                                                   24m
hashicorp     consul-connect-consul-dns      ClusterIP      10.100.152.144   <none>                                                                   53/TCP,53/UDP                                                             16m
hashicorp     consul-connect-consul-server   ClusterIP      None             <none>                                                                   8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   16m
hashicorp     consul-connect-consul-ui       LoadBalancer   10.100.27.89     a45764982a377466888a55b42b6dd752-268952251.us-west-1.elb.amazonaws.com   80:30979/TCP                                                              16m
kong          kong-kong-proxy                LoadBalancer   10.100.251.2     aea3aec28f585467e95521be14cfb212-818134820.us-west-1.elb.amazonaws.com   80:32702/TCP,443:31347/TCP                                                23s
kube-system   kube-dns                       ClusterIP      10.100.0.10      <none>                                                                   53/UDP,53/TCP                                                             24m
</pre>


3. Check the Kong Proxy

Hit Kong Proxy through the Load Balancer provisioned by AWS:

<pre>
$ http af52b0b3c274c4959ac4e8b5cef00b01-105761001.us-west-2.elb.amazonaws.com
HTTP/1.1 404 Not Found
Connection: keep-alive
Content-Length: 48
Content-Type: application/json; charset=utf-8
Date: Tue, 06 Oct 2020 12:43:24 GMT
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
kubectl exec -ti kong-kong-6f784b6686-szd6v -n kong -- /bin/sh
Defaulting container name to ingress-controller.
Use 'kubectl describe pod/kong-kong-6f784b6686-szd6v -n kong' to see all of the containers in this pod.
/ $ nslookup benigno1.service.consul
Server:		10.100.0.10
Address:	10.100.0.10:53

Name:	benigno1.service.consul
Address: 192.168.1.58
Name:	benigno1.service.consul
Address: 192.168.29.24


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
    configuration.konghq.com: do-not-preserve-host
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

Testing the Ingress
<pre>
http af52b0b3c274c4959ac4e8b5cef00b01-105761001.us-west-2.elb.amazonaws.com/benignoroute
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 36
Content-Type: text/html; charset=utf-8
Date: Wed, 16 Sep 2020 20:37:22 GMT
Server: Werkzeug/1.0.1 Python/3.8.3
Via: kong/2.1.3
X-Kong-Proxy-Latency: 4
X-Kong-Upstream-Latency: 2

Hello World, Benigno, Canary Release
</pre>

while [ 1 ]; do curl http://192.168.99.231:30688/benignoroute; sleep 1; echo; done
</pre>

2. Create a Kong Service based on the Sidecar
Get the Client Certificate Id:
<pre>
$ http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/certificates | jq -r .data[].id
a1c9f2cf-d449-4779-bffb-567e5768cbd4
</pre>

Use the id to create the Kong Service and Kong Route. Notice that the Kong Service refers to the FQDN of the Kubernetes Service <b>web-sidecar</b> previously deployed:
<pre>
http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/services name=sidecarservice \
url='https://web-sidecar.default.svc.cluster.local:20000' \
client_certificate:='{"id": "a1c9f2cf-d449-4779-bffb-567e5768cbd4"}'

http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/services/sidecarservice/routes name='route1' paths:='["/route1"]'
</pre>


3. Consume the Kong Routes
<pre>
$ http ac9c11495f0084fa490fb3604a7fa17f-190377106.us-west-2.elb.amazonaws.com/route1
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 624
Content-Type: text/plain; charset=utf-8
Date: Mon, 05 Oct 2020 13:34:32 GMT
Vary: Origin
Via: kong/2.1.4
X-Kong-Proxy-Latency: 35
X-Kong-Upstream-Latency: 40

{
    "body": "Hello World",
    "code": 200,
    "duration": "36.271775ms",
    "end_time": "2020-10-05T13:34:32.602988",
    "ip_addresses": [
        "192.168.25.245"
    ],
    "name": "web",
    "start_time": "2020-10-05T13:34:32.566716",
    "type": "HTTP",
    "upstream_calls": [
        {
            "body": "Response from API v1",
            "code": 200,
            "duration": "414.066µs",
            "end_time": "2020-10-05T13:34:32.602004",
            "ip_addresses": [
                "192.168.17.150"
            ],
            "name": "api-v1",
            "start_time": "2020-10-05T13:34:32.601590",
            "type": "HTTP",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}
</pre>


6. Define an intention to control the communication between the two microservices:
Using Consul CLI installed locally run:
<pre>
consul intention create -deny web api
</pre>

<pre>
$ http ac9c11495f0084fa490fb3604a7fa17f-190377106.us-west-2.elb.amazonaws.com/route1
HTTP/1.1 500 Internal Server Error
Connection: keep-alive
Content-Length: 419
Content-Type: text/plain; charset=utf-8
Date: Mon, 05 Oct 2020 14:09:18 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 2
RateLimit-Reset: 42
Vary: Origin
Via: kong/2.1.4
X-Kong-Proxy-Latency: 18
X-Kong-Upstream-Latency: 39

{
    "code": 500,
    "duration": "36.707335ms",
    "end_time": "2020-10-05T14:09:18.373399",
    "ip_addresses": [
        "192.168.25.245"
    ],
    "name": "web",
    "start_time": "2020-10-05T14:09:18.336692",
    "type": "HTTP",
    "upstream_calls": [
        {
            "code": -1,
            "error": "Error communicating with upstream service: Get http://localhost:9091/: EOF",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}
</pre>

8. Delete the intention to allow the communication again
<pre>
consul intention delete web api
</pre>



## Step 5: Implement a Rate Limiting policy with Kong for Kubernetes

1. Apply a Rate Limiting policy to the Kong Route using the specific Plugin
<pre>
http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/routes/route1/plugins name=rate-limiting config:='{"minute": 3}'
</pre>

2. Consume the Route
The Rate Limiting counter is shown when the request is sent:
<pre>
$ http ac9c11495f0084fa490fb3604a7fa17f-190377106.us-west-2.elb.amazonaws.com/route1
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 623
Content-Type: text/plain; charset=utf-8
Date: Mon, 05 Oct 2020 13:36:09 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 2
RateLimit-Reset: 51
Vary: Origin
Via: kong/2.1.4
X-Kong-Proxy-Latency: 34
X-Kong-Upstream-Latency: 47
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 2

{
    "body": "Hello World",
    "code": 200,
    "duration": "43.630069ms",
    "end_time": "2020-10-05T13:36:09.096722",
    "ip_addresses": [
        "192.168.25.245"
    ],
    "name": "web",
    "start_time": "2020-10-05T13:36:09.053092",
    "type": "HTTP",
    "upstream_calls": [
        {
            "body": "Response from API v1",
            "code": 200,
            "duration": "90.763µs",
            "end_time": "2020-10-05T13:36:09.095924",
            "ip_addresses": [
                "192.168.17.150"
            ],
            "name": "api-v1",
            "start_time": "2020-10-05T13:36:09.095834",
            "type": "HTTP",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}
</pre>


A specific 429 error is received when hitting the Route for the fourth time within the same minute:

<pre>
$ http ac9c11495f0084fa490fb3604a7fa17f-190377106.us-west-2.elb.amazonaws.com/route1
HTTP/1.1 429 Too Many Requests
Connection: keep-alive
Content-Length: 41
Content-Type: application/json; charset=utf-8
Date: Mon, 05 Oct 2020 13:36:13 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 0
RateLimit-Reset: 47
Retry-After: 47
Server: kong/2.1.4
X-Kong-Response-Latency: 2
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 0

{
    "message": "API rate limit exceeded"
}
</pre>





Consul - Minikube Installation
https://learn.hashicorp.com/consul/kubernetes/kubernetes-reference
https://learn.hashicorp.com/consul/kubernetes/minikube
https://www.consul.io/docs/k8s/service-sync
https://www.consul.io/docs/k8s/helm
https://www.hashicorp.com/blog/consul-and-kubernetes-service-catalog-sync/
https://www.consul.io/docs/k8s/dns


minikube start --driver=virtualbox --memory=8192


Installing Consul

Getting Consul Connect Helm Charts
helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul
helm fetch hashicorp/consul


consul-values.yml
global:
  datacenter: dc1
  image: "consul:1.8.3"

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
  enabled: true





Installing Consul
kubectl create namespace hashicorp
helm install consul hashicorp/consul -n hashicorp -f consul-values.yml


$ kubectl get pod --all-namespaces
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
hashicorp     consul-consul-lrqxp                1/1     Running   0          2m47s
hashicorp     consul-consul-server-0             1/1     Running   0          2m47s
kube-system   coredns-f9fd979d6-h2cvh            1/1     Running   1          23h
kube-system   etcd-minikube                      1/1     Running   1          23h
kube-system   kube-apiserver-minikube            1/1     Running   1          23h
kube-system   kube-controller-manager-minikube   1/1     Running   1          23h
kube-system   kube-proxy-vmbqj                   1/1     Running   1          23h
kube-system   kube-scheduler-minikube            1/1     Running   1          23h
kube-system   storage-provisioner                1/1     Running   2          23h




$ kubectl get pod --all-namespaces -o wide
NAMESPACE     NAME                                         READY   STATUS    RESTARTS   AGE     IP               NODE       NOMINATED NODE   READINESS GATES
default       benigno-v1-7d8ccdc66b-s89qv                  1/1     Running   0          4m4s    172.17.0.6       minikube   <none>           <none>
default       busybox                                      1/1     Running   0          70s     172.17.0.7       minikube   <none>           <none>
hashicorp     consul-consul-f6gn9                          1/1     Running   0          6m5s    172.17.0.3       minikube   <none>           <none>
hashicorp     consul-consul-server-0                       1/1     Running   0          6m5s    172.17.0.5       minikube   <none>           <none>
hashicorp     consul-consul-sync-catalog-68b75f5cf-j27mn   1/1     Running   0          6m5s    172.17.0.4       minikube   <none>           <none>
kube-system   coredns-f9fd979d6-pbsfm                      1/1     Running   0          8m6s    172.17.0.2       minikube   <none>           <none>
kube-system   etcd-minikube                                1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   kube-apiserver-minikube                      1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   kube-controller-manager-minikube             1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   kube-proxy-df5tr                             1/1     Running   0          8m7s    192.168.99.231   minikube   <none>           <none>
kube-system   kube-scheduler-minikube                      1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   storage-provisioner                          1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>




$ minikube ip
192.168.99.231









Deploying Benigno
kubectl delete -f deployment_benigno_v1.yaml
kubectl delete -f service_benigno.yaml

kubectl port-forward consul-consul-server-0 -n hashicorp 8500:8500


deployment_benigno_v1.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: benigno-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: benigno
      version: v1
  template:
    metadata:
      labels:
        app: benigno
        version: v1
    spec:
      containers:
      - name: benigno
        image: claudioacquaviva/benigno
        ports:
        - containerPort: 5000



service_benigno.yaml

apiVersion: v1
kind: Service
metadata:
  name: benigno-v1
  labels:
    app: benigno-v1
spec:
  type: ClusterIP
  ports:
  - port: 5000
    name: http
  selector:
    app: benigno
    version: v1






kubectl apply -f deployment_benigno_v1.yaml
kubectl apply -f service_benigno.yaml




$ kubectl get pod --all-namespaces
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
default       benigno-v1-7d8ccdc66b-c6hvr        1/1     Running   0          6s
hashicorp     consul-consul-lrqxp                1/1     Running   0          5m24s
hashicorp     consul-consul-server-0             1/1     Running   0          5m24s
kube-system   coredns-f9fd979d6-h2cvh            1/1     Running   1          23h
kube-system   etcd-minikube                      1/1     Running   1          23h
kube-system   kube-apiserver-minikube            1/1     Running   1          23h
kube-system   kube-controller-manager-minikube   1/1     Running   1          23h
kube-system   kube-proxy-vmbqj                   1/1     Running   1          23h
kube-system   kube-scheduler-minikube            1/1     Running   1          23h
kube-system   storage-provisioner                1/1     Running   2          23h


$ kubectl get service --all-namespaces
NAMESPACE     NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                   AGE
default       benigno                ClusterIP      10.103.192.87    <none>        5000/TCP                                                                  19s
default       kubernetes             ClusterIP      10.96.0.1        <none>        443/TCP                                                                   23h
hashicorp     consul-consul-dns      ClusterIP      10.107.241.195   <none>        53/TCP,53/UDP                                                             5m37s
hashicorp     consul-consul-server   ClusterIP      None             <none>        8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   5m37s
hashicorp     consul-consul-ui       LoadBalancer   10.107.114.104   <pending>     80:30888/TCP                                                              5m37s
kube-system   kube-dns               ClusterIP      10.96.0.10       <none>        53/UDP,53/TCP,9153/TCP                                                    23h


kubectl port-forward service/benigno-v1 5000:5000

$ http :5000
HTTP/1.0 200 OK
Content-Length: 20
Content-Type: text/html; charset=utf-8
Date: Tue, 15 Sep 2020 13:22:25 GMT
Server: Werkzeug/1.0.1 Python/3.8.3

Hello World, Benigno





Consul Service
$ http :8500/v1/catalog/services
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 107
Content-Type: application/json
Date: Tue, 15 Sep 2020 14:51:06 GMT
Vary: Accept-Encoding
X-Consul-Effective-Consistency: leader
X-Consul-Index: 44
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0

{
    "benigno-v1-default": [
        "k8s"
    ],
    "consul": [],
    "consul-consul-dns-hashicorp": [
        "k8s"
    ],
    "consul-consul-server-hashicorp": [
        "k8s"
    ],
    "kubernetes-default": [
        "k8s"
    ]
}


$ http :8500/v1/catalog/service/benigno-v1-default
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 334
Content-Type: application/json
Date: Tue, 15 Sep 2020 14:51:27 GMT
Vary: Accept-Encoding
X-Consul-Effective-Consistency: leader
X-Consul-Index: 44
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0

[
    {
        "Address": "127.0.0.1",
        "CreateIndex": 44,
        "Datacenter": "dc1",
        "ID": "",
        "ModifyIndex": 44,
        "Node": "k8s-sync",
        "NodeMeta": {
            "external-source": "kubernetes"
        },
        "ServiceAddress": "172.17.0.6",
        "ServiceConnect": {},
        "ServiceEnableTagOverride": false,
        "ServiceID": "benigno-v1-default-36cb73f45c0a",
        "ServiceKind": "",
        "ServiceMeta": {
            "external-k8s-ns": "default",
            "external-source": "kubernetes",
            "port-http": "5000"
        },
        "ServiceName": "benigno-v1-default",
        "ServicePort": 5000,
        "ServiceProxy": {
            "Expose": {},
            "MeshGateway": {}
        },
        "ServiceTags": [
            "k8s"
        ],
        "ServiceWeights": {
            "Passing": 1,
            "Warning": 1
        },
        "TaggedAddresses": null
    }
]



$ http :8500/v1/health/service/benigno-v1-default
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 336
Content-Type: application/json
Date: Tue, 15 Sep 2020 14:51:47 GMT
Vary: Accept-Encoding
X-Consul-Effective-Consistency: leader
X-Consul-Index: 44
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0

[
    {
        "Checks": [],
        "Node": {
            "Address": "127.0.0.1",
            "CreateIndex": 16,
            "Datacenter": "dc1",
            "ID": "",
            "Meta": {
                "external-source": "kubernetes"
            },
            "ModifyIndex": 16,
            "Node": "k8s-sync",
            "TaggedAddresses": null
        },
        "Service": {
            "Address": "172.17.0.6",
            "Connect": {},
            "CreateIndex": 44,
            "EnableTagOverride": false,
            "ID": "benigno-v1-default-36cb73f45c0a",
            "Meta": {
                "external-k8s-ns": "default",
                "external-source": "kubernetes",
                "port-http": "5000"
            },
            "ModifyIndex": 44,
            "Port": 5000,
            "Proxy": {
                "Expose": {},
                "MeshGateway": {}
            },
            "Service": "benigno-v1-default",
            "Tags": [
                "k8s"
            ],
            "Weights": {
                "Passing": 1,
                "Warning": 1
            }
        }
    }
]





Sending DNS Requests - busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox:1.28
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always



kubectl apply -f busybox.yaml

Send a request to Consul Server which is Pod address is 172.17.0.3

$ kubectl get pod --all-namespaces -o wide
NAMESPACE     NAME                                         READY   STATUS    RESTARTS   AGE     IP               NODE       NOMINATED NODE   READINESS GATES
default       benigno-v1-7d8ccdc66b-s89qv                  1/1     Running   0          4m4s    172.17.0.6       minikube   <none>           <none>
default       busybox                                      1/1     Running   0          70s     172.17.0.7       minikube   <none>           <none>
hashicorp     consul-consul-f6gn9                          1/1     Running   0          6m5s    172.17.0.3       minikube   <none>           <none>
hashicorp     consul-consul-server-0                       1/1     Running   0          6m5s    172.17.0.5       minikube   <none>           <none>
hashicorp     consul-consul-sync-catalog-68b75f5cf-j27mn   1/1     Running   0          6m5s    172.17.0.4       minikube   <none>           <none>
kube-system   coredns-f9fd979d6-pbsfm                      1/1     Running   0          8m6s    172.17.0.2       minikube   <none>           <none>
kube-system   etcd-minikube                                1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   kube-apiserver-minikube                      1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   kube-controller-manager-minikube             1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   kube-proxy-df5tr                             1/1     Running   0          8m7s    192.168.99.231   minikube   <none>           <none>
kube-system   kube-scheduler-minikube                      1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>
kube-system   storage-provisioner                          1/1     Running   0          8m11s   192.168.99.231   minikube   <none>           <none>





$ kubectl exec -ti busybox /bin/sh
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
/ # nslookup benigno-v1-default.service.consul 172.17.0.3:8600
Server:    172.17.0.3
Address 1: 172.17.0.3 minikube.node.dc1.consul

Name:      benigno-v1-default.service.consul
Address 1: 172.17.0.6 benigno-v1-default.service.dc1.consul
/ # 







Configuring Consul DNS - consul_dns.yaml
$ kubectl get service consul-consul-dns -n hashicorp -o jsonpath='{.spec.clusterIP}'
10.105.0.130


$ kubectl edit configmap coredns -n kube-system
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
        forward . 10.105.0.130
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


Testing Consul DNS - job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dns
spec:
  template:
    spec:
      containers:
        - name: dns
          image: anubhavmishra/tiny-tools
          command: ['dig', 'benigno-v1-default.service.dc1.consul']
      restartPolicy: Never
  backoffLimit: 4




$ kubectl apply -f job.yaml
job.batch/dns created


$ kubectl get pods | grep dns
dns-vmz7k                     0/1     Completed   0          51s

$ kubectl logs dns-vmz7k

; <<>> DiG 9.11.2-P1 <<>> benigno-v1-default.service.dc1.consul
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 41181
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;benigno-v1-default.service.dc1.consul. IN A

;; ANSWER SECTION:
benigno-v1-default.service.dc1.consul. 5 IN A	172.17.0.6

;; Query time: 1 msec
;; SERVER: 10.96.0.10#53(10.96.0.10)
;; WHEN: Tue Sep 15 15:00:48 UTC 2020
;; MSG SIZE  rcvd: 119






$ kubectl delete -f job.yaml
$ kubectl delete job dns



Modify Magnanimo code to consume Benigno Consul Service
In order to get the Microservices connected, Magnanimo has to use the Consul Service DNS, which will be benigno1.service.consul

from flask import Flask
from datetime import datetime
import requests

app = Flask(__name__)

@app.route('/')
def index():
    return 'Hello World, Magnanimo', 200

@app.route('/sentence')
def sentence():
    return 'Hello World, Magnanimo - Kong', 200

@app.route('/hello')
def hello():
    return 'Hello World, Magnanimo: %s' % (datetime.now())

@app.route('/hw2')
def hw2():
    r = requests.get("http://benigno:5000/hello")
    return r.text

@app.route('/hw3')
def hw3():
    r = requests.get("http://benigno1.service.consul:5000/hello")
    return r.text

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=4000)


After updating Magnanimo's code, create a new Docker image for it.

docker build -t claudioacquaviva/magnanimo_consul .
docker push claudioacquaviva/magnanimo_consul



Deploying Magnanimo
deployment_magnanimo.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: magnanimo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: magnanimo
  template:
    metadata:
      labels:
        app: magnanimo
    spec:
      containers:
      - name: magnanimo
        image: claudioacquaviva/magnanimo_consul
        ports:
        - containerPort: 4000


service_magnanimo.yaml

apiVersion: v1
kind: Service
metadata:
  name: magnanimo
  labels:
    app: magnanimo
spec:
  type: ClusterIP
  ports:
  - port: 4000
    name: http
  selector:
    app: magnanimo



kubectl apply -f deployment_magnanimo.yaml
kubectl apply -f service_magnanimo.yaml

kubectl port-forward service/magnanimo 4000:4000

$ http :4000
HTTP/1.0 200 OK
Content-Length: 22
Content-Type: text/html; charset=utf-8
Date: Tue, 15 Sep 2020 15:02:01 GMT
Server: Werkzeug/1.0.1 Python/3.8.3

Hello World, Magnanimo



$ http :4000/hw3
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Length: 290
Content-Type: text/html; charset=utf-8
Date: Tue, 15 Sep 2020 15:02:04 GMT
Server: Werkzeug/1.0.1 Python/3.8.3

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<title>500 Internal Server Error</title>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error and was unable to complete your request. Either the server is overloaded or there is an error in the application.</p>







Consul Service Load Balancing

Deploying Benigno Canary Release
kubectl apply -f deployment_benigno_rc.yaml
kubectl apply -f service_benigno_rc.yaml

kubectl port-forward hashicorp-consul-server-0 8500:8500

$ http :8500/v1/catalog/services
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 122
Content-Type: application/json
Date: Tue, 15 Sep 2020 15:05:51 GMT
Vary: Accept-Encoding
X-Consul-Effective-Consistency: leader
X-Consul-Index: 294
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0

{
    "benigno-v1-default": [
        "k8s"
    ],
    "benigno-v2-default": [
        "k8s"
    ],
    "consul": [],
    "consul-consul-dns-hashicorp": [
        "k8s"
    ],
    "consul-consul-server-hashicorp": [
        "k8s"
    ],
    "kubernetes-default": [
        "k8s"
    ],
    "magnanimo-default": [
        "k8s"
    ]
}


$ http :8500/v1/catalog/service/benigno-v1-default
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 334
Content-Type: application/json
Date: Tue, 15 Sep 2020 15:06:16 GMT
Vary: Accept-Encoding
X-Consul-Effective-Consistency: leader
X-Consul-Index: 44
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0

[
    {
        "Address": "127.0.0.1",
        "CreateIndex": 44,
        "Datacenter": "dc1",
        "ID": "",
        "ModifyIndex": 44,
        "Node": "k8s-sync",
        "NodeMeta": {
            "external-source": "kubernetes"
        },
        "ServiceAddress": "172.17.0.6",
        "ServiceConnect": {},
        "ServiceEnableTagOverride": false,
        "ServiceID": "benigno-v1-default-36cb73f45c0a",
        "ServiceKind": "",
        "ServiceMeta": {
            "external-k8s-ns": "default",
            "external-source": "kubernetes",
            "port-http": "5000"
        },
        "ServiceName": "benigno-v1-default",
        "ServicePort": 5000,
        "ServiceProxy": {
            "Expose": {},
            "MeshGateway": {}
        },
        "ServiceTags": [
            "k8s"
        ],
        "ServiceWeights": {
            "Passing": 1,
            "Warning": 1
        },
        "TaggedAddresses": null
    }
]


$ http :8500/v1/catalog/service/benigno-v2-default
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 334
Content-Type: application/json
Date: Tue, 15 Sep 2020 15:06:40 GMT
Vary: Accept-Encoding
X-Consul-Effective-Consistency: leader
X-Consul-Index: 294
X-Consul-Knownleader: true
X-Consul-Lastcontact: 0

[
    {
        "Address": "127.0.0.1",
        "CreateIndex": 294,
        "Datacenter": "dc1",
        "ID": "",
        "ModifyIndex": 294,
        "Node": "k8s-sync",
        "NodeMeta": {
            "external-source": "kubernetes"
        },
        "ServiceAddress": "172.17.0.9",
        "ServiceConnect": {},
        "ServiceEnableTagOverride": false,
        "ServiceID": "benigno-v2-default-174c34d4f2ae",
        "ServiceKind": "",
        "ServiceMeta": {
            "external-k8s-ns": "default",
            "external-source": "kubernetes",
            "port-http": "5000"
        },
        "ServiceName": "benigno-v2-default",
        "ServicePort": 5000,
        "ServiceProxy": {
            "Expose": {},
            "MeshGateway": {}
        },
        "ServiceTags": [
            "k8s"
        ],
        "ServiceWeights": {
            "Passing": 1,
            "Warning": 1
        },
        "TaggedAddresses": null
    }
]




ben0.json
{
  "ID": "ben0",
  "Name": "benigno1",
  "Tags": ["primary"],
  "Address": "172.17.0.6",
  "Port": 5000,
  "weights": {
    "passing": 1,
    "warning": 1
  }
}




ben1.json
{
  "ID": "ben1",
  "Name": "benigno1",
  "Tags": ["secondary"],
  "Address": "172.17.0.9",
  "Port": 5000,
  "weights": {
    "passing": 99,
    "warning": 1
  }
}



http put :8500/v1/agent/service/register < ben0.json
http put :8500/v1/agent/service/register < ben1.json

http :8500/v1/agent/services
http :8500/v1/agent/service/ben0
http :8500/v1/agent/service/ben1

$ http :8500/v1/agent/health/service/name/benigno1
HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Length: 249
Content-Type: application/json
Date: Wed, 16 Sep 2020 18:55:12 GMT
Vary: Accept-Encoding
X-Consul-Reason: passing

[
    {
        "AggregatedStatus": "passing",
        "Checks": [],
        "Service": {
            "Address": "172.17.0.9",
            "EnableTagOverride": false,
            "ID": "ben1",
            "Meta": {},
            "Port": 5000,
            "Service": "benigno1",
            "TaggedAddresses": {
                "lan_ipv4": {
                    "Address": "172.17.0.9",
                    "Port": 5000
                },
                "wan_ipv4": {
                    "Address": "172.17.0.9",
                    "Port": 5000
                }
            },
            "Tags": [
                "secondary"
            ],
            "Weights": {
                "Passing": 99,
                "Warning": 1
            }
        }
    },
    {
        "AggregatedStatus": "passing",
        "Checks": [],
        "Service": {
            "Address": "172.17.0.6",
            "EnableTagOverride": false,
            "ID": "ben0",
            "Meta": {},
            "Port": 5000,
            "Service": "benigno1",
            "TaggedAddresses": {
                "lan_ipv4": {
                    "Address": "172.17.0.6",
                    "Port": 5000
                },
                "wan_ipv4": {
                    "Address": "172.17.0.6",
                    "Port": 5000
                }
            },
            "Tags": [
                "primary"
            ],
            "Weights": {
                "Passing": 1,
                "Warning": 1
            }
        }
    }
]


$ kubectl get service --all-namespaces
NAMESPACE     NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP               PORT(S)                                                                   AGE
default       benigno-v1             ClusterIP      10.109.43.73    <none>                    5000/TCP                                                                  29h
default       benigno-v2             ClusterIP      10.100.80.136   <none>                    5000/TCP                                                                  29h
default       kubernetes             ClusterIP      10.96.0.1       <none>                    443/TCP                                                                   30h
default       magnanimo              ClusterIP      10.109.1.23     <none>                    4000/TCP                                                                  87m
hashicorp     benigno1               ExternalName   <none>          benigno1.service.consul   <none>                                                                    111m
hashicorp     consul                 ExternalName   <none>          consul.service.consul     <none>                                                                    29h
hashicorp     consul-consul-dns      ClusterIP      10.105.0.130    <none>                    53/TCP,53/UDP                                                             29h
hashicorp     consul-consul-server   ClusterIP      None            <none>                    8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   29h
hashicorp     consul-consul-ui       LoadBalancer   10.104.155.34   <pending>                 80:32379/TCP                                                              29h
kube-system   kube-dns               ClusterIP      10.96.0.10      <none>                    53/UDP,53/TCP,9153/TCP                                                    30h




If you want to delete the service run:

http put :8500/v1/agent/service/deregister/ben0
http put :8500/v1/agent/service/deregister/ben1


Sending DNS Requests
$ kubectl exec -ti busybox /bin/sh
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
/ # nslookup benigno1.service.consul
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      benigno1.service.consul
Address 1: 172.17.0.9 172-17-0-9.benigno-v2.default.svc.cluster.local
Address 2: 172.17.0.6 172-17-0-6.benigno-v1.default.svc.cluster.local
/ # 





Sending requests
If you want to see the different responses coming from both releases, run this simple script:

kubectl port-forward service/magnanimo 4000:4000

while true;
 do sleep 1;
 http :4000/hw3;
 echo -e '\n\n\n\n'$(date);
done

while [ 1 ]; do curl http://localhost:4000/hw3; sleep 1; echo; done







Kong Settings

Setting the Kong Repository
$ helm repo add kong https://charts.konghq.com
"kong" has been added to your repositories

$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "kong" chart repository
Update Complete. ⎈ Happy Helming!⎈ 

$ helm repo ls
NAME   	URL                               
kong   	https://charts.konghq.com

If you want to delete the repository run:
$ helm repo rm kong


Installing K4K8S
$ kubectl create namespace kong

$ helm install kong kong/kong -n kong \
--set ingressController.installCRDs=false

Deleting K4K8S
If you want to uninstall K4K8S run:
$ helm uninstall kong -n kong

 
Checking the Installation
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                         READY   STATUS      RESTARTS   AGE
default       benigno-v1-7d8ccdc66b-s89qv                  1/1     Running     0          123m
default       benigno-v2-65d889f545-7gbmc                  1/1     Running     0          107m
default       busybox                                      1/1     Running     1          120m
default       dns-vmz7k                                    0/1     Completed   0          112m
default       magnanimo-5bb7bb95bb-rmvnc                   1/1     Running     0          83m
hashicorp     consul-consul-f6gn9                          1/1     Running     0          125m
hashicorp     consul-consul-server-0                       1/1     Running     0          125m
hashicorp     consul-consul-sync-catalog-68b75f5cf-j27mn   1/1     Running     0          125m
kong          kong-kong-55b764dbc7-5vz5g                   2/2     Running     2          60s
kube-system   coredns-f9fd979d6-pbsfm                      1/1     Running     0          127m
kube-system   etcd-minikube                                1/1     Running     0          127m
kube-system   kube-apiserver-minikube                      1/1     Running     0          127m
kube-system   kube-controller-manager-minikube             1/1     Running     0          127m
kube-system   kube-proxy-df5tr                             1/1     Running     0          127m
kube-system   kube-scheduler-minikube                      1/1     Running     0          127m
kube-system   storage-provisioner                          1/1     Running     0          127m



$ kubectl get service --all-namespaces
NAMESPACE     NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP                      PORT(S)                                                                   AGE
default       benigno-v1             ClusterIP      10.109.43.73     <none>                           5000/TCP                                                                  123m
default       benigno-v2             ClusterIP      10.100.80.136    <none>                           5000/TCP                                                                  107m
default       kubernetes             ClusterIP      10.96.0.1        <none>                           443/TCP                                                                   127m
default       magnanimo              ClusterIP      10.105.109.199   <none>                           4000/TCP                                                                  111m
hashicorp     benigno-service        ExternalName   <none>           benigno-service.service.consul   <none>                                                                    95m
hashicorp     consul                 ExternalName   <none>           consul.service.consul            <none>                                                                    124m
hashicorp     consul-consul-dns      ClusterIP      10.105.0.130     <none>                           53/TCP,53/UDP                                                             125m
hashicorp     consul-consul-server   ClusterIP      None             <none>                           8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   125m
hashicorp     consul-consul-ui       LoadBalancer   10.104.155.34    <pending>                        80:32379/TCP                                                              125m
kong          kong-kong-proxy        LoadBalancer   10.98.126.247    <pending>                        80:30688/TCP,443:31664/TCP                                                90s
kube-system   kube-dns               ClusterIP      10.96.0.10       <none>                           53/UDP,53/TCP,9153/TCP                                                    127m




$ http 192.168.99.231:30688
HTTP/1.1 404 Not Found
Connection: keep-alive
Content-Length: 48
Content-Type: application/json; charset=utf-8
Date: Tue, 15 Sep 2020 16:54:34 GMT
Server: kong/2.1.3
X-Kong-Response-Latency: 0

{
    "message": "no Route matched with those values"
}





Registering the Kong Ingress - benignoroute.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: benignoroute
  namespace: hashicorp
  annotations:
    konghq.com/strip-path: "true"
spec:
  rules:
  - http:
      paths:
        - path: /benignoroute
          backend:
            serviceName: benigno1
            servicePort: 5000


$ kubectl apply -f benignoroute.yml

Testing the Ingress
$ http 192.168.99.231:30688/benignoroute
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 36
Content-Type: text/html; charset=utf-8
Date: Wed, 16 Sep 2020 20:37:22 GMT
Server: Werkzeug/1.0.1 Python/3.8.3
Via: kong/2.1.3
X-Kong-Proxy-Latency: 4
X-Kong-Upstream-Latency: 2

Hello World, Benigno, Canary Release


while [ 1 ]; do curl http://192.168.99.231:30688/benignoroute; sleep 1; echo; done


Registering the Kong Ingress - magnanimoroute.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: magnanimoroute
  annotations:
    konghq.com/strip-path: "true"
spec:
  rules:
  - http:
      paths:
        - path: /magnanimoroute
          backend:
            serviceName: magnanimo
            servicePort: 4000


$ kubectl apply -f magnanimoroute.yml

Testing the Ingress
$ http 192.168.99.231:30688/magnanimoroute
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 36
Content-Type: text/html; charset=utf-8
Date: Wed, 16 Sep 2020 20:37:22 GMT
Server: Werkzeug/1.0.1 Python/3.8.3
Via: kong/2.1.3
X-Kong-Proxy-Latency: 4
X-Kong-Upstream-Latency: 2

Hello World, Benigno, Canary Release


while [ 1 ]; do curl http://192.168.99.231:30688/magnanimoroute/hw3; sleep 1; echo; done

