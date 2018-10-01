# Hybrid Windows/Linux Kubernetes using acs-engine

## Generate and deploy ARM templates

az group create -n ACS-Hybrid -l westeurope

Fill-in public key data and Service Prinicipal ID and secret before run the template generate command

acs-engine generate clusterTemplate.json

az group deployment create \
--resource-group ACS-Hybrid \
--template-file _output/hybridk8s/azuredeploy.json \
--parameters _output/hybridk8s/azuredeploy.parameters.json

## Grab the context and put it in a config file

Get-Content .\_output\hybridk8s\kubeconfig\kubeconfig.westeurope.json | Out-File $HOME\.kube\config -Append

(or)

az acs kubernetes get-credentials -n {acs-name} -g {resource-group-name}

## Helm/Tiller

Install Helm. Make sure Tiller is installed and up-to-date.

helm init --upgrade

## Deploy app

helm install stable/nginx-ingress --name nginx-ingress -f values.yaml

kubectl get service (to grab the ip address of nginx ingress controller)

(az network dns record-set a add-record -n *.apps -g dns -z example.com--ipv4-address <IP of ingress service>) # to map dns

kubectl apply -f service
				 ingress
				 deploy
				 

# get windows nodes

kubectl get node -l beta.kubernetes.io/os=windows

# access dashboard

Note: not a preffered way, contains security issues

- apply dashboard-admin.yaml manifest

- kubectl proxy

- go to: http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/


# Scenario 2 (Let's Encrypt + KubeLego)

## Install the nginx ingress controller
An ingress controller makes it easy to expose services to the outside world without the need to set up additional load balancers for each new service. We can install the nginx ingress controller using Helm. Again, we use node selectors to ensure it is placed on Linux nodes.

$ helm install --name nginx-ingress \
    --set controller.nodeSelector."beta\.kubernetes\.io\/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io\/os"=linux \
    stable/nginx-ingress
An ingress controller provides a centralized service for routing incoming HTTP requests based on host name to the corresponding services inside the cluster.

## Install Kube-Lego (Let's Encrypt)
Let's Encrypt is a certificate authority that provides an automated way to obtain free SSL certificates. It's extremely easy to integrate it into the nginx ingress controller using a project called [Kube-Lego](https://github.com/jetstack/kube-lego). We can also install this using Helm. We need to provide an email address.

$ helm install --name kube-lego \
    --set config.LEGO_EMAIL=<your-email-address> \
    --set config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory \
    --set nodeSelector."beta\.kubernetes\.io\/os"=linux \
    stable/kube-lego

## Add a wildcard DNS entry
To finish our setup, we need to add a wildcard DNS entry that points to the IP address of our ingress controller. With the wildcard entry in place, we can easily add new services without adding any more DNS entries. And with Kube-Lego installed, we automatically get SSL certs too!

For instance, we can set up a wildcard DNS for *.k8s.domain.com. When we create a new service, we can simply specify its hostname in the form of {servicename}.k8s.domain.com in its ingress resource, and the nginx ingress controller will know how to route traffic to it.

## Deploy a hybrid Linux/Windows app

We'll be running Redis in a Linux container, and an ASP.NET Web Forms application in a Windows container. The Web Forms app will be externally exposed via the ingress controller, and it will use Redis to store data.

### Redis

kubectl create -f https://raw.githubusercontent.com/anthonychu/acs-k8s-multi-agent-pool-demo/master/redis.yaml

### ASP.NET

https://raw.githubusercontent.com/anthonychu/acs-k8s-multi-agent-pool-demo/master/aspnet-webforms-redis-sample.yaml

There are 2 values named HOSTNAME. Replace them with a hostname that matches the wildcard DNS that we set up earlier. (e.g. counter.k8s.domain.com).

kubectl create -f aspnet-webforms-redis-sample.yaml

This will create a deployment for a simple ASP.NET app, plus a service and an ingress resource for it.

#### How this works

- The kubernetes.io/ingress.class: "nginx" annotation and the host on the ingress resource instruct the nginx ingress controller to route traffic with the specified host name to the service.
- The kubernetes.io/tls-acme: "true" annotation on the ingress resource instructs Kube-Lego to obtain and manage SSL certs for the ingress' host name using Let's Encrypt.
- The REDIS_HOST environment variable in the application's container is set to redis.default.svc.cluster.local. This fully qualified DNS name will resolve to the Redis service inside the cluster.

To scale the applicaion: kubectl scale --replicas=3 deployment aspnet-redis