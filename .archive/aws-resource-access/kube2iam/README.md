# Install kube2iam

```
kubectl apply -f kube2iam.yaml
```

## Granting Access to Pods

1. Create the IAM role (let's call it `my-role`) with appropriate access to AWS resources.  

2. Enable `Trust Relationship` between the newly created role and role attached to Kubernetes cluster nodes. 
	- Go to the newly created role in AWS console and Select `Trust relationships` tab
	- Click on `Edit trust relationship`
	- Add the following content to the policy:
	```
	   {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "<ARN_KUBERNETES_NODES_IAM_ROLE>"
      },
      "Action": "sts:AssumeRole"
    }
	```
	- Enable Assume Role for Node Pool IAM roles. Add the following content to Nodes IAM policy:
	```
		{
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": [
                "arn:aws:iam::810085094893:instance-profile/*"
            ]
        }
	```

3. Add the IAM role's name to Deployment as an annotation
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
