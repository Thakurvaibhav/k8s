# Kubernetes monitoring in less than 5 minutes

Kubelet natively exposes cadvisor metrics at https://kubernetes.default.svc:443/api/v1/nodes/<node-name>/proxy/metrics/cadvisor and we can use a prometheus server to scrape this endpoint. These metrics can then be visualized using Grafana. Metrics can alse be scraped from pods and service endpoints if they expose metircs on /metrics (as in the case of nginx-ingress-controller), alternatively you can sepcify custom scrape target in the prometheus config map. 

Setup:

1. If you have not already deployed the nginx-ingress then
    - Comment out statement 191 to 210 or Uncomment statement 183 or 184 depending          upon your cluster setup.
2. Deployment: kubectl deploy -f k8s/monitoring/monitoring.yaml
3. Once grafana is running:
 	- Access grafana at grafana.yourdomain.com in case of Ingress or http://<LB-IP>:3000 in case of type: LoadBalancer
 	- Add DataSource: 
 	  - Name: DS_PROMETHEUS - Type: Prometheus 
 	  - URL: http://prometheus-service:8080 
 	  - Save and Test 0. You can now build your custon dashboards or simply import dashboards from grafana.net. Dasboard #315 and #1471 are good to start with.

Note:

1. A Cluster-binding role is already being created by the config. The role currently has admin permissions, however you can modify it to a viewer role only.
