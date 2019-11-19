# Elasticsearch Logging Stack

Logging Stack for Kubernetes cluster and deployed applications. 

## Setup for fluentbit based logging:

`kubectl apply -f ./fluent-bit`

## Setup for filebeat based logging:

`kubectl apply -f ./flebeat` 

## Setup for fluentd based logging:

`kubectl apply -f ./fluentd`

## Deploy Kibana

`kubectl apply -f kibana.yaml`
Kibana Endpoint:  `http://<pub-ip-kibana-service>:5601/`

### Note: 

1. Make sure you updated the config-map as per your use case. Mulitine JSON handling has been taken care of, please change the regex acc to app logs.

2. The Dockerfile for the fluentd image can be found [here](https://github.com/Thakurvaibhav/docker-library/tree/master/fluentd)

3. Update the endpoint for your ES cluster in fluent-bit/filebeat/fluentd Daemon Set config. 
```   
...	
	spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:0.12.17
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch.elasticsearch"
...
```

4. Similarly update the cluster name and endpoint in the kibana configuration as well.
```
...
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana-oss:6.2.2
        env:
        - name: CLUSTER_NAME
          value: vt-es
        - name: ELASTICSEARCH_URL
          value: http://elasticsearch.elasticsearch:9200
...
```

5. Elasticsearch can be deployed using [this](https://github.com/Thakurvaibhav/k8s/tree/master/databases/elasticsearch)
6. Access for Kibana can be either through public enpoint/Ingress or even an Internal LB (recommended) for your GKE cluster. 
7. Add more parsers in the config map depending upon your use case. 




