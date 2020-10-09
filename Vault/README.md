# Consul Service Discovery and <p> Kong for Kubernetes

From Kong API Gateway perspective, using Consul as its Service Discovery infrastructure is one of the most well-known and common integration use cases. This exercise shows how to integrate Kong for Kubernetes (K4K8S), the Kong Ingress Controller based on the Kong API Gateway, with Consul Service Discovery running on an Kubernetes EKS Cluster.

Kong for Kubernetes can implement all sort of policies to protect the Ingresses defined to expose Kubernetes services to external Consumers including Rate Limiting, API Keys, OAuth/OIDC grants, etc.

The following picture describes the Kong for Kubernetes Ingress Controller and Consul Service Discovery implementing a Canary Release:
<img src="https://github.com/Kong/hashicorp-consul-blogposts/blob/main/Consul/artifacts/architecture.png" width="800" />


#  System Requirements

- A Kubernetes Cluster. This exercise was done on an AWS EKS Cluster. Both Consul Connect and Kong Enterprise support any Kubernetes distribution.
- kubectl
- Helm 3.x
- Consul CLI
- HTTPie and Curl.


#  Installation Process

## Step 1: Consul Installation

1. Add HashiCorp repo to your local Helm installation.


http :8001/services name=vaultservice url='http://httpbin.org'
http :8001/services/vaultservice/routes name='vaultroute' paths:='["/vaultroute"]'





Creating a vault:
A Vault object represents the connection between Kong and a Vault server. It defines the connection and authentication information used to communicate with the Vault API. This allows different instances of the vault-auth plugin to communicate with different Vault servers, providing a flexible deployment and consumption model

http delete :8001/vaults/kong-auth
http :8001/vaults

$ http -f post :8001/vaults name=kong-auth mount=cubbyhole protocol=http host=vault port=8200 vault_token=s.yVK23kmguE4UaDpIqhnhj7sG
HTTP/1.1 201 Created
Access-Control-Allow-Origin: *
Connection: keep-alive
Content-Length: 220
Content-Type: application/json; charset=utf-8
Date: Thu, 29 Aug 2019 04:16:35 GMT
Server: kong/0.36-1-enterprise-edition
X-Kong-Admin-Request-ID: YSuWjFEMXmPLsQfxL0nF191aKe2Hx5da

{
    "created_at": 1567052195,
    "host": "vault",
    "id": "c8da83a1-d4f6-429a-9405-9bfa0c60da17",
    "mount": "cubbyhole",
    "name": "kong-auth",
    "port": 8200,
    "protocol": "http",
    "updated_at": 1567052195,
    "vault_token": "s.yVK23kmguE4UaDpIqhnhj7sG"
}









Creating a consumer
$ http -f post :8001/consumers username=consumer1
HTTP/1.1 201 Created
Access-Control-Allow-Origin: *
Connection: keep-alive
Content-Length: 130
Content-Type: application/json; charset=utf-8
Date: Thu, 29 Aug 2019 03:53:25 GMT
Server: kong/0.36-1-enterprise-edition
X-Kong-Admin-Request-ID: SPKGRa8IHBS0qKeR6R14GTzAi6AhAj9k

{
    "created_at": 1567050805,
    "custom_id": null,
    "id": "eb63759a-7ffa-4f1b-82c1-eb734e3eb6f5",
    "tags": null,
    "type": 0,
    "username": "consumer1"
}








Creating a access/secret token pair for the consumer
$ http -f post :8001/vaults/kong-auth/credentials/consumer1
HTTP/1.1 201 Created
Access-Control-Allow-Origin: *
Connection: keep-alive
Content-Length: 202
Content-Type: application/json; charset=utf-8
Date: Thu, 29 Aug 2019 04:17:33 GMT
Server: kong/0.36-1-enterprise-edition
X-Kong-Admin-Request-ID: 6DgdRs1Bsvqp3rw59rQ8332h5oLuWnTl

{
    "data": {
        "access_token": "oEfl3QTGx7m225t1eZOPhvBsUUP74F3Y",
        "consumer": {
            "id": "eb63759a-7ffa-4f1b-82c1-eb734e3eb6f5"
        },
        "created_at": 1567052253,
        "secret_token": "C1P0WEmK3JjuP7s5h5u2xcFrcqrdjSHJ",
        "ttl": null
    }
}







http -f post :8001/routes/vaultroute/plugins name=vault-auth config.vault.id=c8da83a1-d4f6-429a-9405-9bfa0c60da17

http :8001/plugins
http delete :8001/plugins/2c51d7fe-c16f-4b05-9e02-87d84c191a7f

http :8000/vaultroute/get access_token:oEfl3QTGx7m225t1eZOPhvBsUUP74F3Y secret_token:C1P0WEmK3JjuP7s5h5u2xcFrcqrdjSHJ
