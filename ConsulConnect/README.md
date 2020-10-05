# Consul Connect Service Mesh and <p> Kong for Kubernetes

Consul Connect is one of the main Service Mesh implementations in the marketplace today. Along with Kong for Kubernetes, we can expose the Service Mesh through APIs to external Consumers as well as protecting it with several policies including Rate Limiting, API Keys, OAuth/OIDC grants, Log Processing, Tracing, etc.

The following picture describes the Kong and Consul Connect Service Mesh architecture.
![Architecture](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/ConsulConnect/artifacts/architecture.png =50x20)


#  System Requirements

- A Kubernetes Cluster. This exercise was done on an AWS EKS Cluster. Both Consul Connect and Kong support any Kubernetes distribution.
- kubectl
- Helm 3.x
- Consul CLI
- HTTPie and Curl.


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
hashicorp     consul-connect-consul-connect-injector-webhook-deployment-c6prh   1/1     Running   0          4m39s
hashicorp     consul-connect-consul-ct4pw                                       1/1     Running   0          4m39s
hashicorp     consul-connect-consul-server-0                                    1/1     Running   0          4m39s
kube-system   aws-node-8w4f4                                                    1/1     Running   0          19m
kube-system   coredns-5946c5d67c-kfzn8                                          1/1     Running   0          26m
kube-system   coredns-5946c5d67c-qrpzv                                          1/1     Running   0          26m
kube-system   kube-proxy-vq6td                                                  1/1     Running   0          19m
</pre>

<pre>
$ kubectl get service --all-namespaces
NAMESPACE     NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                                                                   AGE
default       kubernetes                                   ClusterIP      10.100.0.1       <none>                                                                    443/TCP                                                                   26m
hashicorp     consul-connect-consul-connect-injector-svc   ClusterIP      10.100.242.102   <none>                                                                    443/TCP                                                                   5m4s
hashicorp     consul-connect-consul-dns                    ClusterIP      10.100.48.214    <none>                                                                    53/TCP,53/UDP                                                             5m4s
hashicorp     consul-connect-consul-server                 ClusterIP      None             <none>                                                                    8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   5m4s
hashicorp     consul-connect-consul-ui                     LoadBalancer   10.100.199.74    a2f6deb05428549a5bac58042dcd796f-1259403994.us-west-2.elb.amazonaws.com   80:30493/TCP                                                              5m4s
kube-system   kube-dns                                     ClusterIP      10.100.0.10      <none>                                                                    53/UDP,53/TCP             
</pre>

Check the Consul Connect services redirecting your browser to Consul UI:
![ConsulConnect](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/ConsulConnect/artifacts/ConsulConnect.png)


## Step 2: Deploy Sample Microservices

This exercise is based on the same Web and API microservices explored in [HashiCorp Learn](https://learn.hashicorp.com/consul/gs-consul-service-mesh/secure-applications-with-consul-service-mesh) web site. Our intent is to implement mTLS connection with Web Service's Sidecar. In order to do it, we need to expose it as a ClusterIP Service. The sidecar is listening to the default port 20000.


1. Deploy Web and API Microservices

Use the following declarations to deploy both microservices, [Web](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/ConsulConnect/artifacts/web.yml) and [API](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/ConsulConnect/artifacts/web.yml)

After the deployment you should see the new Kubernetes Pods as well as the new Consul Connect Services.
<pre>
kubectl apply -f api.yml
kubectl apply -f web.yml
</pre>

<pre>
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
</pre>


![Web&API](https://github.com/Kong/hashicorp-consul-blogposts/blob/main/ConsulConnect/artifacts/ConsulConnectServices.png)


## Step 3: Kong for Kubernetes (K4K8S) Installation
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
helm install kong kong/kong -n kong \
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
</pre>

2. Check the installation

<pre>
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
</pre>

<pre>
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
</pre>



3. Check the Kong Proxy

Hit Kong Proxy through the Load Balancer provisioned by AWS:

<pre>
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
</pre>

The return message is coming from Kong for Kubernetes, saying there's no API defined yet.


4. Check the Kong REST Admin port
<pre>
$ http abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001 | jq .version
"2.1.4"
</pre>




## Step 4: Consul Digital Certificates and Private Key

Issue the Digital Certificates and Private Key consuming the Consul specific APIs:

1. On a terminal expose the Consul Server Service:
<pre>
$ kubectl port-forward service/consul-connect-consul-server -n hashicorp 8500:8500
Forwarding from 127.0.0.1:8500 -> 8500
Forwarding from [::1]:8500 -> 8500
Handling connection for 8500
</pre>

2. On another terminal run the following command to get the Digital Certificates and Private Key:
<pre>
http :8500/v1/connect/ca/roots | jq -r .Roots[].RootCert > ca.crt
http :8500/v1/agent/connect/ca/leaf/web | jq -r .CertPEM > cert.pem
http :8500/v1/agent/connect/ca/leaf/web | jq -r .PrivateKeyPEM > cert.key
</pre>

After running the command you should see three files:
<pre>
ca.crt: CA's Digital Certificate
cert.pem: Server Digital Certificate
cert.key: Server Private Key
</pre>



## Step 5: Define Kong Service and Route

1. Insert the Digital Certificates and Private Key in Kong:
<pre>
$ curl -sX POST http://abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/ca_certificates -F "cert=@./ca.crt"

$ curl -sX POST http://abc541cc57000442cba78705b2e897cd-1988459246.us-west-2.elb.amazonaws.com:8001/certificates \
    -F "cert=@./cert.pem" \
    -F "key=@./cert.key"
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

