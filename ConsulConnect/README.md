# Consul Connect Service Mesh and <p> Kong Enterprise

Consul Connect is one of the main Service Mesh implementations in the marketplace today. Along with Kong Enterprise, we can expose the Service Mesh through APIs to external Consumers as well as protecting it with several policies including Rate Limiting, API Keys, OAuth/OIDC grants, Log Processing, Tracing, etc.

The following picture describes the Ingress Gateway, Ingress Controller and Service Mesh architecture.
![Architecture](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/ConsulConnect/artifacts/architecture.png)


#  System Requirements

- A Kubernetes Cluster. This exercise was done on an AWS EKS Cluster. Both Consul Connect and Kong Enterprise support any Kubernetes distribution.
- kubectl
- Helm 3.x
- Consul CLI locally installed.
- HTTPie or Curl.


#  Installation Process

## Step 1: Consul Connect Installation

1. Add HashiCorp repo to your local Helm installation.

<pre>
helm repo add hashicorp https://helm.releases.hashicorp.com
</pre>

2. Use the following [YAML file](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/consul-connect.yml) to install Consul Connect.

<pre>
global:
  datacenter: dc1
  image: "consul:1.8.3"
  imageK8S: "hashicorp/consul-k8s:0.18.1"
  imageEnvoy: "envoyproxy/envoy-alpine:v1.14.4"

# Expose the Consul UI through this LoadBalancer
ui:
  service:
    type: LoadBalancer

# Allow Consul to inject the Connect proxy into Kubernetes containers
connectInject:
  enabled: true


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
helm install consul-connect -n hashicorp hashicorp/consul -f consul-connect.yml
</pre>

5. Check the installation

<pre>
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-6wp52   1/1     Running   0          48s
hashicorp     consul-connect-consul-hgqr7                                       1/1     Running   0          48s
hashicorp     consul-connect-consul-server-0                                    1/1     Running   0          48s
kube-system   aws-node-85w7d                                                    1/1     Running   0          3m54s
kube-system   coredns-7dd54bc488-mzq8k                                          1/1     Running   0          9m36s
kube-system   coredns-7dd54bc488-wlxtv                                          1/1     Running   0          9m36s
kube-system   kube-proxy-52z8t                                                  1/1     Running   0          3m54s
</pre>

<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                                  PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                       443/TCP                                                                   10m
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.168.143   <none>                                                                       443/TCP                                                                   69s
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.5.224     <none>                                                                       53/TCP,53/UDP                                                             69s
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                       8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   69s
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.182.175   aa392ef1354e74656b439860e404b518-1774317557.ca-central-1.elb.amazonaws.com   80:30365/TCP                                                              69s
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                       53/UDP,53/TCP                                                             10m
</pre>

Check the Consul Connect services redirecting your browser to Consul UI:
![ConsulConnect](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/ConsulConnect.png)


## Step 2: Deploy Sample Microservices

This exercise will use the same Web and API microservices explored in [HashiCorp Learn](https://learn.hashicorp.com/consul/gs-consul-service-mesh/secure-applications-with-consul-service-mesh) web site.

1. Deploy Web and API Microservices

Use the following declarations to deploy both microservices, [Web](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/web.yml) and [API](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/api.yml)

After the deployment you should see the new Kubernetes Pods as well as the new Consul Connect Services.
<pre>
kubectl apply -f api.yml
kubectl apply -f web.yml
</pre>

<pre>
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
default       api-deployment-v1-85cc8c9977-qpnsv                                3/3     Running   0          91s
default       web-deployment-76dcfdcc8f-sbh4d                                   3/3     Running   0          86s
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-6wp52   1/1     Running   0          7m31s
hashicorp     consul-connect-consul-hgqr7                                       1/1     Running   0          7m31s
hashicorp     consul-connect-consul-server-0                                    1/1     Running   0          7m31s
kube-system   aws-node-85w7d                                                    1/1     Running   0          10m
kube-system   coredns-7dd54bc488-mzq8k                                          1/1     Running   0          16m
kube-system   coredns-7dd54bc488-wlxtv                                          1/1     Running   0          16m
kube-system   kube-proxy-52z8t                                                  1/1     Running   0          10m
</pre>


![Web&API](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/webapi.png)


## Step 3: Kong for Kubernetes (K4K8S) Installation
1. Install Kong for Kubernetes

The original Kong [YAML file](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/all-in-one-dbless-consulconnect.yml) used for the installation has been updated in three settings:<p>
. an annotation to instruct Consul to inject the sidecar in Kong for Kubernetes pod.<p>
. another annotation specifing the Service Upstream.<p>
. Kong deployment name to "kong".<p>

Install Kong for Kubernetes with <b>kubectl</b>
<pre>
kubectl apply -f all-in-one-dbless-consulconnect.yml
</pre>

2. Check the installation

<pre>
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
default       api-deployment-v1-85cc8c9977-qpnsv                                3/3     Running   0          10m
default       web-deployment-76dcfdcc8f-sbh4d                                   3/3     Running   0          10m
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-6wp52   1/1     Running   0          16m
hashicorp     consul-connect-consul-hgqr7                                       1/1     Running   0          16m
hashicorp     consul-connect-consul-server-0                                    1/1     Running   0          16m
kong          ingress-kong-58c75d4f58-vj49d                                     4/4     Running   0          32s
kube-system   aws-node-85w7d                                                    1/1     Running   0          20m
kube-system   coredns-7dd54bc488-mzq8k                                          1/1     Running   0          25m
kube-system   coredns-7dd54bc488-wlxtv                                          1/1     Running   0          25m
kube-system   kube-proxy-52z8t                                                  1/1     Running   0          20m
</pre>

<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                                        PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                             443/TCP                                                                   26m
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.168.143   <none>                                                                             443/TCP                                                                   17m
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.5.224     <none>                                                                             53/TCP,53/UDP                                                             17m
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                             8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   17m
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.182.175   aa392ef1354e74656b439860e404b518-1774317557.ca-central-1.elb.amazonaws.com         80:30365/TCP                                                              17m
kong          kong-proxy                                   LoadBalancer   10.100.242.168   adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com   80:30205/TCP,443:31212/TCP                                                56s
kong          kong-validation-webhook                      ClusterIP      10.100.121.172   <none>                                                                             443/TCP                                                                   55s
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                             53/UDP,53/TCP                                                             26m
</pre>

Run <b>kubectl describe pod ingress-kong-58c75d4f58-vj49d -n kong</b> to check the 4 containers inside of it: the two Kong for Kubernetes original ones and the other two injected by Consul Connect.

<pre>
$ kubectl describe pod ingress-kong-58c75d4f58-vj49d -n kong
Name:         ingress-kong-58c75d4f58-vj49d
Namespace:    kong
Priority:     0
Node:         ip-192-168-88-105.ca-central-1.compute.internal/192.168.88.105
Start Time:   Sat, 05 Sep 2020 12:11:47 -0300
Labels:       app=ingress-kong
              pod-template-hash=58c75d4f58
Annotations:  consul.hashicorp.com/connect-inject: true
              consul.hashicorp.com/connect-inject-status: injected
              consul.hashicorp.com/connect-service: kong
              consul.hashicorp.com/connect-service-port: proxy
              consul.hashicorp.com/connect-service-upstreams: web:9090
              kubernetes.io/psp: eks.privileged
              kuma.io/gateway: enabled
              prometheus.io/port: 8100
              prometheus.io/scrape: true
              traffic.sidecar.istio.io/includeInboundPorts: 
Status:       Running
IP:           192.168.85.56
..........
Containers:
  kong:
    Container ID:   docker://1f56f9de82cf1407fe775dffeee93761c40b9065e3413d86f4c44a03d3c1cff7
    Image:          kong:2.0
    Image ID:       docker-pullable://kong@sha256:694e8a2b046a28a846029e0e6b00f9087d644fab94435c872514c0673053087c
    Ports:          8000/TCP, 8443/TCP, 8100/TCP
..........
  ingress-controller:
    Container ID:   docker://0893a66be776bdcdf891d3800176e2e902711aca12dbf6ce575c0b1289abff39
    Image:          kong-docker-kubernetes-ingress-controller.bintray.io/kong-ingress-controller:0.9.1
    Image ID:       docker-pullable://kong-docker-kubernetes-ingress-controller.bintray.io/kong-ingress-controller@sha256:4651b737a07303dc81a377a8d9679e160d8ba152042a67ccb9c89f305a3d0895
    Port:           8080/TCP
..........
  consul-connect-envoy-sidecar:
    Container ID:  docker://495ac9961c2c2380ba23d12c972379e386d3c8a82aa2622ab31adf949f0e1b57
    Image:         envoyproxy/envoy-alpine:v1.13.0
    Image ID:      docker-pullable://envoyproxy/envoy-alpine@sha256:19f3b361450e31f68b46f891b0c8726041739f44ab9b90aecbca5f426c0d2eaf
    Port:          <none>
..........
  consul-connect-lifecycle-sidecar:
    Container ID:  docker://f07f677c95520f67e204e03de89181fffcfc835d9e15728ffad3debef2b0a0f2
    Image:         hashicorp/consul-k8s:0.18.1
    Image ID:      docker-pullable://hashicorp/consul-k8s@sha256:e88ae391bb4aa3f31b688f48a5291d65e962f9301392e4bdf57213e65265116a
    Port:          <none>
..........
</pre>

Check the Consul Connect services again:
![Services](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/ConsulConnectServices.png)



3. Consume the Ingress Controller

Hit the Ingress Controller through the Load Balancer provisioned by AWS:

<pre>
$ http adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com
HTTP/1.1 404 Not Found
Connection: keep-alive
Content-Length: 48
Content-Type: application/json; charset=utf-8
Date: Sat, 05 Sep 2020 15:26:36 GMT
Server: kong/2.0.5
X-Kong-Response-Latency: 0

{
    "message": "no Route matched with those values"
}
</pre>

The return message is coming from Kong for Kubernetes Ingress Controller, saying there's no API defined yet.



## Step 4: Define an Ingress

1. In order to expose the Web microservice, define an Ingress in Kong using Kubernetes CRD like this:
<pre>
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: web
  namespace: default
  annotations:
    konghq.com/strip-path: "true"
spec:
  rules:
  - http:
      paths:
        - path: /web
          backend:
            serviceName: localhost
            servicePort: 9090
</pre>

The Ingress is based on the <b>"localhost"</b> Kubernetes Service and defines a path "<b>/web</b>" to expose it to the consumers. A copy of this file can be found [here](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/web-ingress.yml)

Notice the Ingress is referencing the loopback address as required by the Consul Connect Sidecar, so it can intercept all the requests going to it.

2. Define an [External Service](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/web-externalservice.yml) to loopback address using another CRD like this:
<pre>
apiVersion: v1
kind: Service
metadata:
  name: localhost
  namespace: default
spec:
  externalName: localhost
  ports:
  - port: 9090
    protocol: TCP
  type: ExternalName
</pre>

3. Apply the both declarations
<pre>
kubectl apply -f web-ingress.yml
kubectl apply -f web-externalservice.yml
</pre>

4. Consume the Ingress
<pre>
$ http adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com/web
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 623
Content-Type: text/plain; charset=utf-8
Date: Sat, 05 Sep 2020 15:29:45 GMT
Vary: Origin
Via: kong/2.0.5
X-Kong-Proxy-Latency: 0
X-Kong-Upstream-Latency: 24

{
    "body": "Hello World",
    "code": 200,
    "duration": "15.327627ms",
    "end_time": "2020-09-05T15:29:45.231809",
    "ip_addresses": [
        "192.168.74.44"
    ],
    "name": "web",
    "start_time": "2020-09-05T15:29:45.216481",
    "type": "HTTP",
    "upstream_calls": [
        {
            "body": "Response from API v1",
            "code": 200,
            "duration": "204.524µs",
            "end_time": "2020-09-05T15:29:45.230780",
            "ip_addresses": [
                "192.168.76.226"
            ],
            "name": "api-v1",
            "start_time": "2020-09-05T15:29:45.230576",
            "type": "HTTP",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}
</pre>

The request has been sent to the Ingress Controller. The path <b>"/web"</b> routes the request to the Web microservice which in its turn calls the API microservice.

5. Define an intention to control the communication between Kong for Kubernetes and Web microservice
Open a local terminal and run:
<pre>
kubectl port-forward consul-connect-consul-server-0 -n hashicorp 8500:8500
</pre>

Open another local terminal and define an intention to control the communication between Kong for Kubernetes and Web microservice:
<pre>
consul intention create -deny kong web
</pre>

<pre>
$ http adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com/web
HTTP/1.1 502 Bad Gateway
Connection: keep-alive
Content-Length: 58
Content-Type: text/plain; charset=utf-8
Date: Sat, 05 Sep 2020 15:32:27 GMT
Server: kong/2.0.5
Via: kong/2.0.5
X-Kong-Proxy-Latency: 11
X-Kong-Upstream-Latency: 91

An invalid response was received from the upstream server
</pre>

6. Delete the intention to allow the communication again
<pre>
consul intention delete kong web
</pre>

7. Define an intention to control the communication between the two microservices:
<pre>
consul intention create -deny web api
</pre>

<pre>
$ http adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com/web
HTTP/1.1 500 Internal Server Error
Connection: keep-alive
Content-Length: 417
Content-Type: text/plain; charset=utf-8
Date: Sat, 05 Sep 2020 15:32:58 GMT
Vary: Origin
Via: kong/2.0.5
X-Kong-Proxy-Latency: 0
X-Kong-Upstream-Latency: 7

{
    "code": 500,
    "duration": "5.208606ms",
    "end_time": "2020-09-05T15:32:58.441107",
    "ip_addresses": [
        "192.168.74.44"
    ],
    "name": "web",
    "start_time": "2020-09-05T15:32:58.435899",
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



## Step 5: Implement a Rate Limiting policy with Kong for Kubernetes Ingress Controller

1. Instantiate a Kong for Kubernetes plugin to define the Rate Limiting policy.

Kong for Kubernetes provides an extensive list of plugin to implement all sort of policies typically enabled at the Ingress Controller layer. Beside Rate Limiting, Caching, OIDC based User and App Authentication, Log Processing, Canary, mTLS, etc. are other examples of policies that can be applied to the Ingresses.

Apply a [declaration](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/ratelimiting.yml) like this to define the Rate Limiting policy using a specific Kong Plugin:
<pre>
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rl-by-minute
config:
  minute: 3
  policy: local
plugin: rate-limiting
</pre>

The declaration instantiates the Rate Limiting plugin defining a policy that allows 3 requests a minute.


2. Instantiate the Kong Plugin
<pre>
kubectl apply -f ratelimiting.yml
</pre>

2. Apply the policy to the Ingress
A policy is applied to an Ingress including a specific annontation to it:
<pre>
kubectl patch ingress web -p '{"metadata":{"annotations":{"plugins.konghq.com":"rl-by-minute"}}}'
</pre>


3. Consume the Ingress
The Rate Limiting counter is shown when the request is sent:
<pre>
$ http adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com/web

HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 621
Content-Type: text/plain; charset=utf-8
Date: Sat, 05 Sep 2020 15:34:42 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 2
RateLimit-Reset: 18
Vary: Origin
Via: kong/2.0.5
X-Kong-Proxy-Latency: 1
X-Kong-Upstream-Latency: 6
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 2

{
    "body": "Hello World",
    "code": 200,
    "duration": "3.697067ms",
    "end_time": "2020-09-05T15:34:42.085906",
    "ip_addresses": [
        "192.168.74.44"
    ],
    "name": "web",
    "start_time": "2020-09-05T15:34:42.082209",
    "type": "HTTP",
    "upstream_calls": [
        {
            "body": "Response from API v1",
            "code": 200,
            "duration": "74.005µs",
            "end_time": "2020-09-05T15:34:42.085387",
            "ip_addresses": [
                "192.168.76.226"
            ],
            "name": "api-v1",
            "start_time": "2020-09-05T15:34:42.085313",
            "type": "HTTP",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}
</pre>


A specific 429 error is received when hitting the Ingress for the fourth time within the same minute:

<pre>
$ http adf044a74744d47faada93adf8a205fc-c34f8a0ef13568ec.elb.ca-central-1.amazonaws.com/web
HTTP/1.1 429 Too Many Requests
Connection: keep-alive
Content-Length: 37
Content-Type: application/json; charset=utf-8
Date: Sat, 05 Sep 2020 15:34:46 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 0
RateLimit-Reset: 14
Retry-After: 14
Server: kong/2.0.5
X-Kong-Response-Latency: 1
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 0

{
    "message": "API rate limit exceeded"
}
</pre>



Kong for Kubernetes and Consul Proxy Ingress - Kubernetes
Reference Architecture

System Requirements
kubectl
Helm 3.x
HTTPie and Curl.

Creating an EKS Cluster
eksctl creates implicitly a specific VPC for our EKS Cluster.

$ eksctl create cluster --name K4K8S-ConsulConnect --version 1.17 --nodegroup-name standard-workers --node-type t3.medium --nodes 1

Deleting the EKS Cluster
In case you need to delete it, run the following command:

eksctl delete cluster --name K4K8S-ConsulConnect


Consul Connect Installation

Setting Consul Connect Helm Charts
helm repo add hashicorp https://helm.releases.hashicorp.com


YAML Declaration - consul-connect.yml
global:
  datacenter: dc1
  image: "consul:1.8.3"
  imageK8S: "hashicorp/consul-k8s:0.18.1"
  imageEnvoy: "envoyproxy/envoy-alpine:v1.14.4"

# Expose the Consul UI through this LoadBalancer
ui:
  service:
    type: LoadBalancer

# Allow Consul to inject the Connect proxy into Kubernetes containers
connectInject:
  enabled: true


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


Consul Connect Installation
Create a Namespace for Consul
kubectl create namespace hashicorp

Install Consul Connect with Helm
helm install consul-connect -n hashicorp hashicorp/consul -f consul-connect.yml

$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                    443/TCP                                                                   26m
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.242.102   <none>                                                                    443/TCP                                                                   5m4s
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.48.214    <none>                                                                    53/TCP,53/UDP                                                             5m4s
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                    8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   5m4s
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.199.74    a2f6deb05428549a5bac58042dcd796f-1259403994.us-west-2.elb.amazonaws.com   80:30493/TCP                                                              5m4s
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                    53/UDP,53/TCP                                                             26m


Check the Consul Connect services redirecting your browser to Consul UI:



Deploy Sample Microservices - api.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment-v1
  labels:
    app: api-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-v1
  template:
    metadata:
      labels:
        app: api-v1
      annotations:
        "consul.hashicorp.com/connect-inject": "true"
    spec:
      containers:
      - name: api
        image: nicholasjackson/fake-service:v0.7.8
        ports:
        - containerPort: 9090
        env:
        - name: "LISTEN_ADDR"
          value: "127.0.0.1:9090"
        - name: "NAME"
          value: "api-v1"
        - name: "MESSAGE"
          value: "Response from API v1"



kubectl apply -f api.yml


Deploy Sample Microservices - web-sidecar.yml
Our intent is to implement mTLS connection with Web Service's Sidecar. In order to do it, we need to expose it as a ClusterIP Service. The sidecar is listening to the default port 20000. Create a "web-sidecarservice.yaml" file like this and apply it with "kubectl":

kubectl apply -f web-sidecar.yml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
      annotations:
        "consul.hashicorp.com/connect-inject": "true"
        "consul.hashicorp.com/connect-service-upstreams": "api:9091"
    spec:
      containers:
      - name: web
        image: nicholasjackson/fake-service:v0.7.8
        ports:
        - containerPort: 9090
        env:
        - name: "LISTEN_ADDR"
          value: "0.0.0.0:9090"
        - name: "UPSTREAM_URIS"
          value: "http://localhost:9091"
        - name: "NAME"
          value: "web"
        - name: "MESSAGE"
          value: "Hello World"

---
apiVersion: v1
kind: Service
metadata:
  name: web-sidecar
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - name: https
    protocol: TCP
    port: 20000
    targetPort: 20000



kubectl apply -f web-sidecar.yml

Checking the Microservices
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
default       api-deployment-v1-85cc8c9977-jbbv2                                3/3     Running   0          63s
default       web-deployment-76dcfdcc8f-2dvn6                                   3/3     Running   0          22s
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-c6prh   1/1     Running   0          4m39s
hashicorp     consul-connect-consul-ct4pw                                       1/1     Running   0          4m39s
hashicorp     consul-connect-consul-server-0                                    1/1     Running   0          4m39s
kube-system   aws-node-8w4f4                                                    1/1     Running   0          19m
kube-system   coredns-5946c5d67c-kfzn8                                          1/1     Running   0          26m
kube-system   coredns-5946c5d67c-qrpzv                                          1/1     Running   0          26m
kube-system   kube-proxy-vq6td                                                  1/1     Running   0          19m


$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                    443/TCP                                                                   26m
default       web-sidecar                                  ClusterIP      10.100.45.250    <none>                                                                    20000/TCP                                                                 45s
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.242.102   <none>                                                                    443/TCP                                                                   5m4s
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.48.214    <none>                                                                    53/TCP,53/UDP                                                             5m4s
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                    8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   5m4s
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.199.74    a2f6deb05428549a5bac58042dcd796f-1259403994.us-west-2.elb.amazonaws.com   80:30493/TCP                                                              5m4s
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                    53/UDP,53/TCP                                                             26m







Kong for Kubernetes Installation
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
--set admin.enabled=true \
--set admin.type=LoadBalancer \
--set admin.http.enabled=true \
--set env.database=postgres \
--set postgresql.enabled=true \
--set postgresql.postgresqlUsername=kong \
--set postgresql.postgresqlDatabase=kong \
--set postgresql.postgresqlPassword=kong \
--set ingressController.enabled=false \
--set ingressController.installCRDs=false


Checking the Installation
Notice that, since we disabled the Controller, the Kong Pod has only one Container running.

$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS      RESTARTS   AGE
default       api-deployment-v1-85cc8c9977-jbbv2                                3/3     Running     0          28m
default       web-deployment-76dcfdcc8f-2dvn6                                   3/3     Running     0          27m
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-c6prh   1/1     Running     0          32m
hashicorp     consul-connect-consul-ct4pw                                       1/1     Running     0          32m
hashicorp     consul-connect-consul-server-0                                    1/1     Running     0          32m
kong          kong-kong-5cd475f445-nsdcq                                        1/1     Running     0          77s
kong          kong-kong-init-migrations-bwhqd                                   0/1     Completed   0          76s
kong          kong-postgresql-0                                                 1/1     Running     0          76s
kube-system   aws-node-8w4f4                                                    1/1     Running     0          47m
kube-system   coredns-5946c5d67c-kfzn8                                          1/1     Running     0          53m
kube-system   coredns-5946c5d67c-qrpzv                                          1/1     Running     0          53m
kube-system   kube-proxy-vq6td                                                  1/1     Running     0          47m



$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                    443/TCP                                                                   53m
default       web-sidecar                                  ClusterIP      10.100.45.250    <none>                                                                    20000/TCP                                                                 27m
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.242.102   <none>                                                                    443/TCP                                                                   31m
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.48.214    <none>                                                                    53/TCP,53/UDP                                                             31m
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                    8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   31m
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.199.74    a2f6deb05428549a5bac58042dcd796f-1259403994.us-west-2.elb.amazonaws.com   80:30493/TCP                                                              31m
kong          kong-kong-admin                              LoadBalancer   10.100.127.202   abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com   8001:31301/TCP,8444:31442/TCP                                             34s
kong          kong-kong-proxy                              LoadBalancer   10.100.31.70     ac9c11495f0084fa490fb3604a7fa17f-190377106.us-west-2.elb.amazonaws.com    80:30579/TCP,443:30425/TCP                                                34s
kong          kong-postgresql                              ClusterIP      10.100.168.65    <none>                                                                    5432/TCP                                                                  34s
kong          kong-postgresql-headless                     ClusterIP      None             <none>                                                                    5432/TCP                                                                  34s
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                    53/UDP,53/TCP                                                             53m






Checking the Proxy
Use the Load Balancer created during the deployment

$ http ac9c11495f0084fa490fb3604a7fa17f-190377106.us-west-2.elb.amazonaws.com
HTTP/1.1 404 Not Found
Connection: keep-alive
Content-Length: 48
Content-Type: application/json; charset=utf-8
Date: Mon, 05 Oct 2020 13:28:52 GMT
Server: kong/2.1.4
X-Kong-Response-Latency: 0

{
    "message": "no Route matched with those values"
}



Checking the Rest Admin API
Try to consume the ELB

$ http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001 | jq .version
"2.1.4"


Deleting Kong Enterprise
helm uninstall kong -n kong
kubectl delete namespace kong




Consul Digital Certificates
Install Consul locally. In MacOS we can use brew
brew install consul

Issue the Digital Certificates and Private Key
On a terminal expose the Consul Server Service:

$ kubectl port-forward service/consul-connect-consul-server -n hashicorp 8500:8500
Forwarding from 127.0.0.1:8500 -> 8500
Forwarding from [::1]:8500 -> 8500
Handling connection for 8500


On another terminal run the following command to get the Digital Certificates and Private Key
http :8500/v1/connect/ca/roots | jq -r .Roots[].RootCert > ca.crt
http :8500/v1/agent/connect/ca/leaf/web | jq -r .CertPEM > cert.pem
http :8500/v1/agent/connect/ca/leaf/web | jq -r .PrivateKeyPEM > cert.key

After running the command you should see three files:
ca.crt: CA's Digital Certificate
cert.pem: Server Digital Certificate
cert.key: Server Private Key














Creating Kong Digital Certificates, Service and Route

Inject the three files in Kong:

$ curl -sX POST http://abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/ca_certificates -F "cert=@./ca.crt"

$ curl -sX POST http://abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/certificates \
    -F "cert=@./cert.pem" \
    -F "key=@./cert.key"


Create a Service based on the Sidecar
Get the Client Certificate Id:

$ http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/certificates | jq -r .data[].id
a1c9f2cf-d449-4779-bffb-567e5768cbd4


Use the id during the Kong Service and Kong Route definition

http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/services name=sidecarservice \
url='https://web-sidecar.default.svc.cluster.local:20000' \
client_certificate:='{"id": "a1c9f2cf-d449-4779-bffb-567e5768cbd4"}'

http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/services/sidecarservice/routes name='route1' paths:='["/route1"]'

Consume the  Kong Enterprise Route
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


Applying a Rate Limiting Policy
We're still able to use Kong Enterprise plugins and define all sort of policies to the routes. For example, here's the Rate Limiting plugin:

http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/routes/route1/plugins name=rate-limiting config:='{"minute": 3}'


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


If we keep sending requests, eventually, we're going to get a specific 429 error code

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



