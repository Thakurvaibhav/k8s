# Consul Helm Chart

This helm chart deploys a highly available, persistent storage backed consul cluster. Orginally forked from [here.](https://github.com/hashicorp/consul-helm)

# Pre-Deploy

1. It is recommended to expose consul-ui over an ingress and not directly using the load balancer. 
2. Set the ui doman at `ui.ingress.host` inside `values.yaml` 
3. Other options can be also we tweaked inside the `values.yaml` file. You can find the full list [here](https://github.com/hashicorp/consul-helm)

# Install the helm chart

### Create the consul namespace

`kubectl create ns consul`

### Deploy the helm chart

`helm install --name <consul-cluster-name> ./consul`

### Access Consul UI 

The UI should now be available at `consul.mydomain.com`
