# Kubernetes Horizontal Pod Auto-Scaling using Prometheus Metrics

Kubernetes HPA by default scales pods using CPU/Memory requirement. However, we sometimes need to scale based on some custom metrics. This will deploy a prometheus adapter which can pull some or all of the metrics available in prometheus. 

### Pre-requisite

1. [Deploy Prometheus](https://github.com/Thakurvaibhav/k8s/tree/master/monitoring#kubernetes-monitoring-and-alerting-in-less-than-5-minutes)
2. [Optional] [Deploy Nginx Pod which exposes VTS Metrics.](https://github.com/Thakurvaibhav/docker-library/tree/master/nginx-vts#nginx-and-vts-exporter-docker-files-and-kubernetes-deployment)

## Deploy Prometheus Adapter
	
1. Generate certifactes which will be used by the metrics adapter: `make certs`

2. Deploy the metrics adapter: `make deploy`


### Test if custom metrics are available: 
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

### Test the value of the available metrics
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