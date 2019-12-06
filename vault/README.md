# Vault Helm Chart

This helm chart deploys a highly available, persistent storage backed consul cluster. Orginally forked from [here.](https://github.com/hashicorp/vault-helm)

# Pre-Deploy

1. Please install consul as per instructions give [here](https://github.com/Thakurvaibhav/k8s/tree/master/consul#consul-helm-chart)
2. It is recommended to expose vault-ui over an ingress and not directly using the load balancer. 
3. Set the ui doman at `ui.ingress.host` inside `values.yaml` 
4. Other options can be also we tweaked inside the `values.yaml` file. You can find the full list [here](https://github.com/hashicorp/vault-helm)

# Install the helm chart

### Create the consul namespace

`kubectl create ns vault`

### Deploy the helm chart

`helm install --name <vault-cluster-name> ./consul`

### Access Vault UI 

The UI should now be available at `vault.mydomain.com`
It will require `Initial Root Token` which we generate below. 


# Unseal Vault Pod

### Create Unseal keys and root token

Exec into one of the pods and generate unseal keys as shown below.

```
root$ kubectl exec -it gotham-vault-0 /bin/sh
/ $ vault operator init -n 1 -t 1
Unseal Key 1: F/cTlLxTzj7WG8ftjZXLy0Tw7xdTRzvg1WxmfVrCLKg=

Initial Root Token: s.mLnvddIsCg86BR3QAWam3Pur

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 1 key to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

Use the `Unseal Key 1` to unseal vault server on the same pod. 

```
/ $ vault operator unseal F/cTlLxTzj7WG8ftjZXLy0Tw7xdTRzvg1WxmfVrCLKg=
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.2.4
Cluster Name           vault-cluster-becc22b7
Cluster ID             f03e2804-3c72-7aa4-9dc4-e04cbe73ee9d
HA Enabled             true
HA Cluster             n/a
HA Mode                standby
Active Node Address    <none>
/ $ exit
``` 

Use the same key to unseal vault server on all the other pods. 
You should now be able to see the service as active on Consul and Vault Status as unseal on the vault UI. 
