# Traefik Ingress Controller

## Setup:

1. Controller: kubectl apply -f traefik/ingress-controller.yaml
2. Controller UI: kubectl apply -f traefik/ui.yaml

## Access:

1. External IP of the created ELB(in case of AWS) or GLB(in case of GKE) can be found by `kubectl get svc -n kube-system`  Service named traefik-ingress-service should have a public ip.
2. In order to test run the following,
	`kubectl apply -f ./traefik/cheese.yaml`
	`kubectl apply -f ./traefik/ingress.yaml` 
	Now, Access the services by making a entry for foo.bar.com and bar.baz.com on your local machine's /etc/hosts
	```
	cat /etc/hosts
	##
    # Host Database
    #
    # localhost is used to configure the loopback interface
    # when the system is booting.  Do not change this entry.
    ##
    127.0.0.1	localhost
    255.255.255.255	broadcasthost
    ::1             localhost
    <pub-ip-lb>   traefik-ui.mydomain.com
    <pub-ip-lb>   cheeses.mydomain.com
    <pub-ip-lb>.  test.host.com
	```
	RUN `curl traefik-ui.mydomain.com` :Should return the UI for traefik\
	RUN `curl cheeses.mydomain.com\stilton` :Should return the stilton page and similarly for others\
    RUN `curl test.host.com`   :Should be redirected to default backend 

##Note:

1. FOR GKE: The user deploying these resources should be cluster admin. You can become cluster admin by `kubectl create clusterrolebinding myname-cluster-admin-binding --clusterrole=cluster-admin --user=<email-for-gcp>`
