Kubelet natively exposes cadvisor metrics at `https://kubernetes.default.svc:443/api/v1/nodes/<node-name>/proxy/metrics/cadvisor` and we can use a prometheus server to scrape this endpoint. These metrics can then be visualized using Grafana.\

Setup:\
	1. If you have not already deployed the nginx-ingress then\
		a. Comment out statement 191 to 210\
		b. Uncomment statement 183 or 184 depending upon your cluster setup.\ 
	2. Deployment: kubectl deploy -f k8s/monitoring/monitoring.yaml\
	3. Once grafana is running:\
	    a. Access grafana at monitoring.yourdomain.com/grafana in case of Ingress or http://<LB-pub-ip>:3000 in case of `type: LoadBalancer`\
		b. Add DataSource:\
			i.   Name: DS_PROMETHEUS\
			ii.  Type: Prometheus\
			iii. URL: http://prometheus-service:8080\
			iv.  Save and Test\
	4. You can now build your custon dashboards or simply import dashboards from grafana.net. Dasboard #315 and #1471 are good to start with.\

Note:\
	1. A Cluster-binding role is already being created by the config. The role currently as admin permissions, however you can modify it to a viewer role only.\