# Kubernetes Horizontal Pod Auto-Scaling using Prometheus Metrics

Kubernetes HPA by default scales pods using CPU/Memory metrics. However, we sometimes need to scale based on some custom metrics. This will deploy a prometheus adapter which can pull some or all of the metrics available in prometheus, which can be used for Pod autoscaling. 

### Pre-requisite

1. [Deploy Prometheus](https://github.com/Thakurvaibhav/k8s/tree/master/monitoring#kubernetes-monitoring-and-alerting-in-less-than-5-minutes)
2. [Optional] [Deploy Nginx Pod which exposes VTS Metrics.](https://github.com/Thakurvaibhav/docker-library/tree/master/nginx-vts#nginx-and-vts-exporter-docker-files-and-kubernetes-deployment)

## Deploy Prometheus Adapter
	
1. Generate certifactes which will be used by the metrics adapter: `make certs`

2. Deploy the metrics adapter: `make deploy`

## Testing the Set-up

### Check if custom metrics are available: 
```
root$ kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .

{
  "kind": "APIResourceList",
  "apiVersion": "v1",
  "groupVersion": "custom.metrics.k8s.io/v1beta1",
  "resources": [
    {
      "name": "pods/nginx_vts_server_requests_per_second",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "namespaces/nginx_vts_server_requests_per_second",
      "singularName": "",
      "namespaced": false,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    }
  ]
}
```

### Check the current value of the available metrics (nginx_vts_server_requests_per_second)
```
root$ kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/nginx/pods/*/nginx_vts_server_requests_per_second" | jq .

{
  "kind": "MetricValueList",
  "apiVersion": "custom.metrics.k8s.io/v1beta1",
  "metadata": {
    "selfLink": "/apis/custom.metrics.k8s.io/v1beta1/namespaces/nginx/pods/%2A/nginx_vts_server_requests_per_second"
  },
  "items": [
    {
      "describedObject": {
        "kind": "Pod",
        "namespace": "nginx",
        "name": "nginx-deployment-65d8df7488-v575j",
        "apiVersion": "/v1"
      },
      "metricName": "nginx_vts_server_requests_per_second",
      "timestamp": "2019-11-19T18:38:21Z",
      "value": "1236m"
    }
  ]
}
```

### Create HPA based on these metrics. 
```
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-custom-hpa
  namespace: nginx
spec:
  scaleTargetRef:
    apiVersion: extensions/v1beta1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metricName: nginx_vts_server_requests_per_second
      targetAverageValue: 4000m
```
Now you can generate requests on your nginx service endpoint and the pod should scale accordingly. 

## Note

1. We are only getting a single custom metric in the prometheus adapter. 
2. In order to get more metrics add rules in `custom-metrics-api/custom-metrics-config-map.yaml` and deploy it. You can find more rules [here](https://github.com/DirectXMan12/k8s-prometheus-adapter/blob/5afd30edcfce7f1914591948ea71ec2b5b34af31/deploy/manifests/custom-metrics-config-map.yaml#L8)
3. Make sure you update the `--prometheus-url` argument in `custom-metrics-api/custom-metrics-apiserver-deployment.yaml` accordingly. Presently it is set to the thanos querier endpoint deployed as a part of Clustered Prometheus Set-Up
