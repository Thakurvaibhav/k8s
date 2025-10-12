# Cluster Autoscaler for Kubernetes on AWS


## Add labels to node groups and modify IAM policy to Scale-In Scale-Out

`kops edit ig nodes`

Now Add the new labels in cloudLabels key.

```
spec:
  cloudLabels:
    k8s.io/cluster-autoscaler/k8s.mydomain.com: ""
    k8s.io/cluster-autoscaler/enabled: ""
    k8s.io/cluster-autoscaler/node-template/label: ""
    kubernetes.io/cluster/k8s.mydomain.com: owned
  ...
  minSize: 2
  maxSize: 5
```

`kops edit cluster`

Now add the policy.

```
...
kind: Cluster
spec:
  additionalPolicies:
    node: |
      [
        {
          "Effect": "Allow",
          "Action": [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeTags",
            "autoscaling:TerminateInstanceInAutoScalingGroup"
          ],
          "Resource": ["*"]
        }
      ]
...
```

### Review updates

`kops update cluster`

### Apply updates

`kops update cluster --yes`

### Check if rolling-update is needed

`kops rolling-update cluster`

### Perform rolling-update if required

`kops rolling-update cluster --yes`


## Install Cluster Autosacaler

```
helm install --name cluster-autoscaler \
            --namespace kube-system \
            --set image.tag=v1.14.6 \
            --set autoDiscovery.clusterName=k8s.mydomain.com \
            --set extraArgs.balance-similar-node-groups=false \
            --set extraArgs.expander=random \
            --set rbac.create=true 
            --set rbac.pspEnabled=true \
            --set awsRegion=us-east-2 \
            --set nodeSelector."node-role\.kubernetes\.io/master"="" \
            --set tolerations[0].effect=NoSchedule \
            --set tolerations[0].key=node-role.kubernetes.io/master \
            --set cloudProvider=aws stable/cluster-autoscaler
```