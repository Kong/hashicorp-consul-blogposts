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

