# Elasticsearch-FluentBit-Kibana based Logging Stack

Logging Stack for Kubernetes cluster and deployed application. 

Setup:

1. kubectl apply -f rbac.yml 
2. kubectl apply -f configmap.yml
3. kubectl apply -f fluent-bit-ds.yml
4. kubectl apply -f kibana.yml

Endpoint:  `http://<pub-ip-kibana-service>:5601/`


Note:

1. Update the endpoint for your ES cluster in fluent-bit Daemon Set config. 
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

2. Similarly update the cluster name and endpoint in the kibana configuration as well.
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

3. Elasticsearch can be deployed by following this: `https://github.com/Thakurvaibhav/k8s/tree/master/databases/elasticsearch`
4. Access for Kibana can be either through public enpoint/Ingress or even an Internal LB (recommended) for your GKE cluster. 
5. Add more parsers in the config map depending upon your use case. 