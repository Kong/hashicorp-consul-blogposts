# Consul Connect Service Mesh and <p> Kong for Kubernetes Ingress Controller

Consul Connect is one of the main Service Mesh implementations in the marketplace today. Along with Kong for Kubernetes Ingress Controller, we can expose the Service Mesh through Ingresses to external Consumers as well as protecting it with several policies including Rate Limiting, API Keys, OAuth/OIDC grants, Log Processing, Tracing, etc.

Besides, Kong for Kubernetes Ingress Controller is not just exposing and protecting the Service Mesh but also being part of the Zero-Trust Security environment implemented by Consul Connect. In other words, just any other existing components inside the Service Mesh, the Ingress Controller has the Envoy Sidecar injected inside of it.

The following picture describes the Ingress Gateway, Ingress Controller and Service Mesh architecture.
![Architecture](https://github.com/hashicorp/consul-kong-ingress-gateway/blob/master/artifacts/architecture.png)


#  System Requirements

- A Kubernetes Cluster. This exercise was done on an AWS EKS Cluster. Both Consul Connect and Kong for Kubernetes support any Kubernetes distribution.
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




Kong Enterprise Services and Consul Proxy Ingress - Kubernetes
Reference Architecture

System Requirements
kubectl
Helm 3.x
HTTPie and Curl.

Creating an EKS Cluster
eksctl creates implicitly a specific VPC for our EKS Cluster.

$ eksctl create cluster --name Kong-ConsulConnect --version 1.17 --nodegroup-name standard-workers --node-type t3.medium --nodes 1

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

kubectl apply -f web-sidecarservice.yaml

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
default       api-deployment-v1-85cc8c9977-wzz2r                                3/3     Running   0          29m
default       web-deployment-76dcfdcc8f-p5g9v                                   3/3     Running   0          55s
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-nvm77   1/1     Running   0          38m
hashicorp     consul-connect-consul-server-0                                    1/1     Running   0          38m
hashicorp     consul-connect-consul-v5jl2                                       1/1     Running   0          38m
kube-system   aws-node-qc9pk                                                    1/1     Running   0          2d
kube-system   coredns-7dd54bc488-24md2                                          1/1     Running   0          2d
kube-system   coredns-7dd54bc488-tkwzn                                          1/1     Running   0          2d
kube-system   kube-proxy-9l2wr                                                  1/1     Running   0          2d








ELB to Kong Enterprise
Go to ELB dashboard and click on "Create Load Balancer".

Click on "Create" for "Classic Load Balancer".

In the "Step 1: Define Load Balancer" page
Load Balancer name: "lb-kongenterprise"
Create LB Inside: choose the VPC created for the EKS Cluster
Load Balancer Protocol:
Load Balancer Protocol: TCP
Load Balancer Port to 81
Instance Protocol: TCP
Instance Port to 32001
Repeat the process to ports 82, 83 and 84 with respective Instances Ports 32002, 32003 and 32004
Availability subnets: choose all the Public Subnets available.

Click on "Next: Assign Security Groups".

In the "Step 2: Assign Security Groups" page
Choose "Create a new security group"
Choose "All TCP" for "Type"
Source: Anywhere

Click on "Next: Configure Security Settings" and "Next: Configure Health Check.

In the "Step 4: Configure Health Check" page choose TCP for the "Ping Protocol".

Click on "Next: Add EC2 Instances".

In the "Step 5: Add EC2 Instances" choose the EC2 created for the EKS Cluster.

Click on "Next: Add Tags", "Review and Create" and "Create".

Check the Load Balancer:

$ aws elb describe-load-balancers --load-balancer lb-kongenterprise
Kong Enterprise Installation
Kong Enterprise Secrets
First of all, create a "kong" namespace
kubectl create namespace kong

Create a secret with your license file
kubectl create secret generic kong-enterprise-license -n kong --from-file=./license

Create a secret for the docker registry
kubectl create secret -n kong docker-registry kong-enterprise-k8s-docker --docker-server=kong-docker-kong-enterprise-edition-docker.bintray.io --docker-username=cacquaviva --docker-password=ffeb00dad08c86c40790bf616d9da289b809385b




Creating session conf for Kong Manager and Kong DevPortal
"admin_gui.session_conf" file
{"cookie_name":"admin_session","secret":"admin-secret","cookie_secure":false,"storage":"kong"}

"portal_session_conf" file
{"cookie_name":"portal_session","secret":"portal-secret","cookie_secure":false,"storage":"kong"}

kubectl create secret generic kong-session-config -n kong --from-file=admin_gui_session_conf --from-file=portal_session_conf


Creating Kong Manager password
kubectl create secret generic kong-enterprise-superuser-password -n kong --from-literal=password=kong


Installing Kong Enterprise without Controller
We're going to use the Helm Charts to install Kong Enterprise. Please, notice that, since we're using NodePort for all Kong Enterprise Services (Manager, Rest Admin API, Portal and Portal API) we're using the url of the previously created ELB lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com

The exception is the Proxy Service. Since we're deploying it as LoadBalancer, EKS will be responsible for instantiating another ELB for us.

After the deployment we'll have two ELBs: one for the Proxy (created automatically for us) and one for the Kong Enterprise Services (created manually by us). 

helm install kong kong/kong -n kong \
--set env.database=postgres \
--set env.password.valueFrom.secretKeyRef.name=kong-enterprise-superuser-password \
--set env.password.valueFrom.secretKeyRef.key=password \
--set env.admin_gui_url=http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:82 \
--set env.admin_api_uri=http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81 \
--set env.portal_gui_host=lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:83 \
--set env.portal_api_url=http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:84 \
--set env.portal_session_conf="\{\"cookie_name\": \"04tm341\"\, \"secret\": \"nothing\"\, \"storage\":\"kong\"\, \"cookie_secure\": false\, \"cookie_samesite\":\"off\"\, \"cookie_lifetime\": 21600\}" \
--set image.repository=kong-docker-kong-enterprise-edition-docker.bintray.io/kong-enterprise-edition \
--set image.tag="2.1.3.1-alpine" \
--set image.pullSecrets[0]=kong-enterprise-k8s-docker \
--set admin.enabled=true \
--set admin.type=NodePort \
--set admin.http.enabled=true \
--set admin.http.servicePort=32001 \
--set admin.http.nodePort=32001 \
--set admin.http.containerPort=32001 \
--set admin.tls.servicePort=32442 \
--set admin.tls.nodePort=32442 \
--set admin.tls.containerPort=32442 \
--set proxy.type=LoadBalancer \
--set proxy.http.servicePort=80 \
--set proxy.http.nodePort=32000 \
--set proxy.http.containerPort=32000 \
--set proxy.tls.servicePort=443 \
--set proxy.tls.nodePort=32443 \
--set proxy.tls.containerPort=32443 \
--set ingressController.enabled=false \
--set postgresql.enabled=true \
--set postgresql.postgresqlUsername=kong \
--set postgresql.postgresqlDatabase=kong \
--set postgresql.postgresqlPassword=kong \
--set enterprise.enabled=true \
--set enterprise.license_secret=kong-enterprise-license \
--set enterprise.portal.enabled=true \
--set enterprise.rbac.enabled=true \
--set enterprise.rbac.session_conf_secret=kong-session-config \
--set enterprise.rbac.admin_gui_auth_conf_secret=admin-gui-session-conf \
--set enterprise.smtp.enabled=false \
--set manager.type=NodePort \
--set manager.http.servicePort=32002 \
--set manager.http.nodePort=32002 \
--set manager.http.containerPort=32002 \
--set manager.tls.servicePort=32445 \
--set manager.tls.nodePort=32445 \
--set manager.tls.containerPort=32445 \
--set portal.enabled=true \
--set portal.type=NodePort \
--set portal.http.servicePort=32003 \
--set portal.http.nodePort=32003 \
--set portal.http.containerPort=32003 \
--set portal.tls.servicePort=32446 \
--set portal.tls.nodePort=32446 \
--set portal.tls.containerPort=32446 \
--set portalapi.type=NodePort \
--set portalapi.http.servicePort=32004 \
--set portalapi.http.nodePort=32004 \
--set portalapi.http.containerPort=32004 \
--set portalapi.tls.servicePort=32447 \
--set portalapi.tls.nodePort=32447 \
--set portalapi.tls.containerPort=32447


Checking the Installation
Notice that, since we disabled the Controller, the Kong Pod has only one Container running.

$ kubectl get pod --all-namespaces
NAMESPACE     NAME                                                              READY   STATUS      RESTARTS   AGE
default       api-deployment-v1-85cc8c9977-rwtmk                                3/3     Running     0          2d14h
default       web-deployment-76dcfdcc8f-cprhh                                   3/3     Running     0          2d13h
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-qqhhk   1/1     Running     0          2d14h
hashicorp     consul-connect-consul-cvth6                                       1/1     Running     0          2d14h
hashicorp     consul-connect-consul-server-0                                    1/1     Running     0          2d14h
kong          kong-kong-79b48b5b59-8bt5v                                        1/1     Running     0          56s
kong          kong-kong-init-migrations-n2gkv                                   0/1     Completed   0          55s
kong          kong-postgresql-0                                                 1/1     Running     0          56s
kube-system   aws-node-vlvds                                                    1/1     Running     0          2d15h
kube-system   coredns-5946c5d67c-86cnr                                          1/1     Running     0          2d15h
kube-system   coredns-5946c5d67c-8qqj5                                          1/1     Running     0          2d15h
kube-system   kube-proxy-v44ln                                                  1/1     Running     0          2d15h


$ kubectl get pvc --all-namespaces
NAMESPACE   NAME                                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
hashicorp   data-hashicorp-consul-connect-consul-server-0   Bound    pvc-ac823df7-4bbe-4ccc-a390-ac5f94d351b2   10Gi       RWO            gp2            2d14h
kong        data-kong-postgresql-0                          Bound    pvc-593beee2-b12d-4ede-a208-a6807a7f53f4   8Gi        RWO            gp2            103s



$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                    443/TCP                                                                   3h12m
default       web-sidecar                                  ClusterIP      10.100.139.204   <none>                                                                    20000/TCP                                                                 78s
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.134.105   <none>                                                                    443/TCP                                                                   95m
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.48.49     <none>                                                                    53/TCP,53/UDP                                                             95m
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                    8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   95m
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.118.185   a6dd6e2039a4742e58ae4759e8034559-1863524997.us-west-2.elb.amazonaws.com   80:30365/TCP                                                              95m
kong          kong-kong-admin                              NodePort       10.100.93.76     <none>                                                                    32001:32001/TCP,32442:32442/TCP                                           81m
kong          kong-kong-manager                            NodePort       10.100.217.42    <none>                                                                    32002:32002/TCP,32445:32445/TCP                                           81m
kong          kong-kong-portal                             NodePort       10.100.138.149   <none>                                                                    32003:32003/TCP,32446:32446/TCP                                           81m
kong          kong-kong-portalapi                          NodePort       10.100.168.93    <none>                                                                    32004:32004/TCP,32447:32447/TCP                                           81m
kong          kong-kong-proxy                              LoadBalancer   10.100.57.126    a24844fb25271421caedebe4ca77b760-1451906635.us-west-2.elb.amazonaws.com   80:32000/TCP,443:32443/TCP                                                81m
kong          kong-postgresql                              ClusterIP      10.100.47.148    <none>                                                                    5432/TCP                                                                  81m
kong          kong-postgresql-headless                     ClusterIP      None             <none>                                                                    5432/TCP                                                                  81m
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                    53/UDP,53/TCP                                                             3h12m







Checking the Proxy
Use the Load Balancer created during the deployment

$ http a24844fb25271421caedebe4ca77b760-1451906635.us-west-2.elb.amazonaws.com
HTTP/1.1 404 Not Found
Connection: keep-alive
Content-Length: 48
Content-Type: application/json; charset=utf-8
Date: Sun, 27 Sep 2020 18:57:01 GMT
Server: kong/2.1.3.1-enterprise-edition
X-Kong-Response-Latency: 3

{
    "message": "no Route matched with those values"
}



Checking the Rest Admin API
We're going to use the same security group created by the proxy load balancer in the load balancer created previously to expose the Kong Enterprise Services (Kong REST API, Kong Manager, Kong DevPortal and Kong DevPortal API).

Go to the Proxy Load Balancer AWS page. Click on security group defined in "Source Security Group".

Select the Security Group with a name like "k8s-elb-...". The description should be something like "Security Group for Kubernetes ELB..."


As you can see the Inbound Rules allow traffic only for ports 80. To make it easier we're going to include all ports.

Click on "Edit inbound rules". Add another Inbound Rule with "All TCP" and Source "Anywhere". Click on "Save Rule"

Include this Security Group in the Source Security Group list for the ELB we created.

Try to consume the ELB

$ http lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81 kong-admin-token:kong | jq .version
"2.1.3.1-enterprise-edition"

Notice that, since we've turned RBAC on, we had to inject the Kong Admin Token in our request.


Checking Kong Manager
Redirect your browser to "http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:82"


Deleting Kong Enterprise
helm uninstall kong -n kong
kubectl delete pvc data-kong-postgresql-0 -n kong

kubectl delete secret docker-registry bintray-kong -n kong
kubectl delete secret kong-session-config -n kong
kubectl delete secret kong-enterprise-license -n kong
kubectl delete namespace kong




Consul Template for Kong Enterprise
Intall consul and consul-template locally. In MacOS we can use brew
brew install consul
brew install consul-template

Create a template for Digital Certificates and Private Key
echo '{{range caRoots}}{{.RootCertPEM}}{{end}}' > ca.crt.tmpl
echo '{{with caLeaf "nginx"}}{{.CertPEM}}{{end}}' > cert.pem.tmpl
echo '{{with caLeaf "nginx"}}{{.PrivateKeyPEM}}{{end}}' > cert.key.tmpl


Create Config file for Consul Template
Consul Template needs a config file to issue digital certificates and private key

cat > kong-ingress-config.hcl << EOF
exec {
  command = "echo 'done'"
}
template {
  source = "ca.crt.tmpl"
  destination = "ca.crt"
}
template {
  source = "cert.pem.tmpl"
  destination = "cert.pem"
}
template {
  source = "cert.key.tmpl"
  destination = "cert.key"
}
EOF


Issue the Digital Certificates and Private Key
On a terminal expose the Consul Server Service:

$ kubectl port-forward service/consul-connect-consul-server -n hashicorp 8500:8500
Forwarding from 127.0.0.1:8500 -> 8500
Forwarding from [::1]:8500 -> 8500
Handling connection for 8500


On another terminal run the following command to get the Digital Certificates and Private Key
$ consul-template -config kong-ingress-config.hcl

After running the command you should see three files:
ca.crt: CA's Digital Certificate
cert.pem: Server Digital Certificate
cert.key: Server Private Key


Creating Kong Enterprise Digital Certificates, Service and Route

Inject the three files in Kong Enterprise:

$ curl -sX POST http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/ca_certificates -F "cert=@./ca.crt" -H 'kong-admin-token:kong'

curl -i -X POST http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/certificates \
    -F "cert=@./cert.pem" \
    -F "key=@./cert.key" \
    -H 'kong-admin-token:kong'


You can check the Certificate in Kong Manager





Create a Service based on the Sidecar
Get the Client Certificate and CA Certificate Ids first

$ http lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/certificates kong-admin-token:kong
HTTP/1.1 200 OK
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:82
Connection: keep-alive
Content-Length: 1238
Content-Type: application/json; charset=utf-8
Date: Sun, 27 Sep 2020 19:35:29 GMT
Server: kong/2.1.3.1-enterprise-edition
X-Kong-Admin-Latency: 47
X-Kong-Admin-Request-ID: bNjIkH36BDWllk9c0Als2uuJdAGmEl28
vary: Origin

{
    "data": [
        {
            "cert": "-----BEGIN CERTIFICATE-----\nMIICQTCCAeegAwIBAgIBCjAKBggqhkjOPQQDAjAwMS4wLAYDVQQDEyVwcmktY3dp\nM214di5jb25zdWwuY2EuOTg3ODQ3ZmYuY29uc3VsMB4XDTIwMDkyNzE5MjEyMVoX\nDTIwMDkzMDE5MjEyMVowLDEqMCgGA1UEAxMhbmdpbnguc3ZjLmRlZmF1bHQuOTg3\nODQ3ZmYuY29uc3VsMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEIN7Mextqo0r4\ntE2ahDBXsGy+nUgMwjysKBcM/esKp3njSzzc3bzerBPd/Zout+H4Uu8mi+90axTN\ncYzLkpfr2aOB9TCB8jAOBgNVHQ8BAf8EBAMCA7gwHQYDVR0lBBYwFAYIKwYBBQUH\nAwIGCCsGAQUFBwMBMAwGA1UdEwEB/wQCMAAwKQYDVR0OBCIEIDi/TGiraXx+LkuF\nTvDnKqQo/vc+9YAu0/wmbrXUAWxIMCsGA1UdIwQkMCKAICgoPRbK2FnsO/GGOyiH\nB6TT5cNDvigDl+doPkEawukxMFsGA1UdEQRUMFKGUHNwaWZmZTovLzk4Nzg0N2Zm\nLWUwZDktMjVhZi02MTJkLTdjMTU2YTBlMzUwNi5jb25zdWwvbnMvZGVmYXVsdC9k\nYy9kYzEvc3ZjL25naW54MAoGCCqGSM49BAMCA0gAMEUCIQC70eQPc75oun0T9qCS\ndk9kbVNRDrXiyZAeP++RsYCW3wIgSelXxsgHTZHBa1v1MsD5eyD8QGzeIHPJWy1k\n0o7YmL8=\n-----END CERTIFICATE-----\n\n",
            "created_at": 1601235206,
            "id": "74ccbe96-4fb8-4131-91ed-3de6815e67a9",
            "key": "-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIEvak5JDtG3G2CXn/aYFWTgtIbMNEMxBKdfyKVIE/mhRoAoGCCqGSM49\nAwEHoUQDQgAEIN7Mextqo0r4tE2ahDBXsGy+nUgMwjysKBcM/esKp3njSzzc3bze\nrBPd/Zout+H4Uu8mi+90axTNcYzLkpfr2Q==\n-----END EC PRIVATE KEY-----\n\n",
            "snis": [],
            "tags": null
        }
    ],
    "next": null
}



$ http lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/ca_certificates kong-admin-token:kong
HTTP/1.1 200 OK
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: http://lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:82
Connection: keep-alive
Content-Length: 983
Content-Type: application/json; charset=utf-8
Date: Sun, 27 Sep 2020 19:36:05 GMT
Server: kong/2.1.3.1-enterprise-edition
X-Kong-Admin-Latency: 40
X-Kong-Admin-Request-ID: bLPLce0wjQFnzkMkFX4xdFxzYyO0MPLZ
vary: Origin

{
    "data": [
        {
            "cert": "-----BEGIN CERTIFICATE-----\nMIICDDCCAbOgAwIBAgIBBzAKBggqhkjOPQQDAjAwMS4wLAYDVQQDEyVwcmktY3dp\nM214di5jb25zdWwuY2EuOTg3ODQ3ZmYuY29uc3VsMB4XDTIwMDkyNzE4NDA1NloX\nDTMwMDkyNzE4NDA1NlowMDEuMCwGA1UEAxMlcHJpLWN3aTNteHYuY29uc3VsLmNh\nLjk4Nzg0N2ZmLmNvbnN1bDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABARG+HSM\nIC5xwClQntmkukYrFbM9pdssLkLuPaK0MS7gFK+kUL6QGgpLRwHb1yA2L1OLMuG2\n5jjL86feXUunILqjgb0wgbowDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMB\nAf8wKQYDVR0OBCIEICgoPRbK2FnsO/GGOyiHB6TT5cNDvigDl+doPkEawukxMCsG\nA1UdIwQkMCKAICgoPRbK2FnsO/GGOyiHB6TT5cNDvigDl+doPkEawukxMD8GA1Ud\nEQQ4MDaGNHNwaWZmZTovLzk4Nzg0N2ZmLWUwZDktMjVhZi02MTJkLTdjMTU2YTBl\nMzUwNi5jb25zdWwwCgYIKoZIzj0EAwIDRwAwRAIgBwPNaH+QuI5e4I9BUq97jhmz\nhiM+4w5IgcyILVRBTCMCIHXTqSX6fkXCm5GMStAMZPSP5XlHxFzvlfWWalcvIyWU\n-----END CERTIFICATE-----\n\n",
            "cert_digest": "6283b9a09200119e22f26d232cd2f49261c89fc80ec034f536534d97b7e5e536",
            "created_at": 1601235125,
            "id": "89568b96-738a-4dab-9031-09670f1f2672",
            "tags": null
        }
    ],
    "next": null
}


Use the ids during the Kong Service and Kong Route definition

http lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/services name=sidecarservice \
url='https://web-sidecar.default.svc.cluster.local:20000' \
client_certificate:='{"id": "74ccbe96-4fb8-4131-91ed-3de6815e67a9"}' \
kong-admin-token:kong

http lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/services/sidecarservice/routes name='route2' paths:='["/route2"]' kong-admin-token:kong


Check both in Kong Manager:




Consume the  Kong Enterprise Route
$ http a24844fb25271421caedebe4ca77b760-1451906635.us-west-2.elb.amazonaws.com/route2
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 623
Content-Type: text/plain; charset=utf-8
Date: Sun, 27 Sep 2020 20:19:44 GMT
Vary: Origin
Via: kong/2.1.3.1-enterprise-edition
X-Kong-Proxy-Latency: 17
X-Kong-Upstream-Latency: 15

{
    "body": "Hello World",
    "code": 200,
    "duration": "12.357462ms",
    "end_time": "2020-09-27T20:19:44.377375",
    "ip_addresses": [
        "192.168.23.95"
    ],
    "name": "web",
    "start_time": "2020-09-27T20:19:44.365017",
    "type": "HTTP",
    "upstream_calls": [
        {
            "body": "Response from API v1",
            "code": 200,
            "duration": "200.886µs",
            "end_time": "2020-09-27T20:19:44.376801",
            "ip_addresses": [
                "192.168.21.197"
            ],
            "name": "api-v1",
            "start_time": "2020-09-27T20:19:44.376600",
            "type": "HTTP",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}





Applying a Rate Limiting Policy
We're still able to use Kong Enterprise plugins and define all sort of policies to the routes. For example, here's the Rate Limiting plugin:

http lb-kongenterprise-157786404.us-west-2.elb.amazonaws.com:81/routes/route2/plugins name=rate-limiting config:='{"minute": 3}' kong-admin-token:kong



$ http a24844fb25271421caedebe4ca77b760-1451906635.us-west-2.elb.amazonaws.com/route2
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 618
Content-Type: text/plain; charset=utf-8
Date: Sun, 27 Sep 2020 20:23:16 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 2
RateLimit-Reset: 44
Vary: Origin
Via: kong/2.1.3.1-enterprise-edition
X-Kong-Proxy-Latency: 47
X-Kong-Upstream-Latency: 10
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 2

{
    "body": "Hello World",
    "code": 200,
    "duration": "7.0177ms",
    "end_time": "2020-09-27T20:23:16.207998",
    "ip_addresses": [
        "192.168.23.95"
    ],
    "name": "web",
    "start_time": "2020-09-27T20:23:16.200980",
    "type": "HTTP",
    "upstream_calls": [
        {
            "body": "Response from API v1",
            "code": 200,
            "duration": "80.53µs",
            "end_time": "2020-09-27T20:23:16.207365",
            "ip_addresses": [
                "192.168.21.197"
            ],
            "name": "api-v1",
            "start_time": "2020-09-27T20:23:16.207285",
            "type": "HTTP",
            "uri": "http://localhost:9091"
        }
    ],
    "uri": "/"
}



If we keep sending requests, eventually, we're going to get a specific 429 error code

$ http a24844fb25271421caedebe4ca77b760-1451906635.us-west-2.elb.amazonaws.com/route2
HTTP/1.1 429 Too Many Requests
Connection: keep-alive
Content-Length: 41
Content-Type: application/json; charset=utf-8
Date: Sun, 27 Sep 2020 20:23:20 GMT
RateLimit-Limit: 3
RateLimit-Remaining: 0
RateLimit-Reset: 40
Retry-After: 40
Server: kong/2.1.3.1-enterprise-edition
X-Kong-Response-Latency: 17
X-RateLimit-Limit-Minute: 3
X-RateLimit-Remaining-Minute: 0

{
    "message": "API rate limit exceeded"
}






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

