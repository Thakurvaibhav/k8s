# Install kiam

## Creating IAM Roles

1. Create the IAM role called `kiam-server`

2. Enable `Trust Relationship` between the newly created role and role attached to Kubernetes cluster master nodes. 
	- Go to the newly created role in AWS console and Select `Trust relationships` tab
	- Click on `Edit trust relationship`
	- Add the following content to the policy:
	```
	   {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "<ARN_KUBERNETES_MASTER_IAM_ROLE>"
      },
      "Action": "sts:AssumeRole"
    }
	```

3. Add inline policy to the `kiam-server` role
   ```
   {
  	 "Version": "2012-10-17",
     "Statement": [
      {
        "Effect": "Allow",
        "Action": [
        	"sts:AssumeRole"
      	 ],
      	"Resource": "*"
      }
  	]
   }
   ```

4. Create the IAM role (let's call it `my-role`) with appropriate access to AWS resources. 

5. Enable `Trust Relationship` between the newly created role and role attached to Kubernetes cluster nodes. 
	- Go to the newly created role in AWS console and Select `Trust relationships` tab
	- Click on `Edit trust relationship`
	- Add the following content to the policy:
	```
	   {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "<ARN_KIAM-SERVER_IAM_ROLE>"
      },
      "Action": "sts:AssumeRole"
    }
	``` 
	- Enable Assume Role for Master Pool IAM roles. Add the following content to Master IAM policy:
	```
		{
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": [
                "<ARN_KIAM-SERVER_IAM_ROLE>"
            ]
        }
	```


## Deploying KIAM

1. Deploy cert-manager
	- Install the CustomResourceDefinition resources separately
		`kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml`
	- Create the namespace for cert-manager
		`kubectl create namespace cert-manager`
	- Label the cert-manager namespace to disable resource validation
		`kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true`
	- Add the Jetstack Helm repository
		`helm repo add jetstack https://charts.jetstack.io`
	- Update your local Helm chart repository cache
		`helm repo update`
	- Install the cert-manager Helm chart
		`helm install --name cert-manager --namespace cert-manager --version v0.8.0 jetstack/cert-manager`
    - This set-up is enough for kiam to work. However detailed Steps can be found [here](https://cert-manager.readthedocs.io/en/latest/getting-started/install/kubernetes.html#steps)

2. Generate CA private key and self-signed certificate for kiam agent-server TLS
	- `openssl genrsa -out ca.key 2048`
	- `openssl req -x509 -new -nodes -key ca.key -subj "/CN=kiam" -out kiam.cert -days 3650 -reqexts v3_req -extensions v3_ca -out ca.crt`
	- Save the CA key pair as a secret in Kubernetes
	    ```
	    kubectl create secret tls kiam-ca-key-pair \
   		  --cert=ca.crt \
   		  --key=ca.key \
   		  --namespace=cert-manager
	    ```
	- Deploy cluster issuer, certificate and issue the certificate
	    `kubectl apply -f kiam/namespace.yaml`
	    `kubectl apply -f kiam/certificate.yaml`

	- Test if certificates are issued correctly
	    `kubectl -n kiam get secret kiam-agent-tls -o yaml`
	    `kubectl -n kiam get secret kiam-server-tls -o yaml`

3.  Annotating Resources
	- Add the IAM role's name to Deployment as an annotation
	  	```
	  	apiVersion: extensions/v1beta1
	  	kind: Deployment
	  	metadata:
	    	name: mydeployment
	    	namespace: default
	  	spec:
	  	...
	    	minReadySeconds: 5
	    	template:
	        	annotations:
	          	iam.amazonaws.com/role: my-role
	      	spec:
	        	containers:
	  	... 
	  	```
	- Add role annotation to the namespace in which pods will run
	  	```
	  	apiVersion: v1
		kind: Namespace
		metadata:
  			name: default
  			annotations:
    			iam.amazonaws.com/permitted: ".*"
	  	```
	  	The default is not to allow any roles. You can use a regex as shown above to allow all roles or can even specify a particular role per namespace. 

4.  Deploy the KIAM server (this will run as a DS on all master nodes)
	`kubectl apply -f kiam-server.yaml`

5.  Deploy the KIAM agent
    `kubectl apply -f kiam-agent.yaml`

## Testing Access

1. Deploy test-pod
```
kubectl apply -f test-deploy.yaml
``` 

2. Exec into the pod and run 
```
curl 169.254.169.254/latest/meta-data/iam/security-credentials/
```
You should get `myrole` as the response. 





