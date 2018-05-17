# Ingress Controllers for AWS and GKE based Kubernetes Clusters

Ingress-Controllers Runs in HA. Immune to Node/Pod failure. Cluster should have atleast 3 workers for the Affinity policy to be respected. 

Setup:



1. AWS: kubectl apply -f aws/ingress-controller.yaml
2. GKE: kubectl apply -f gke/ingress-controller.yaml


Access:
1. External IP of the created ELB(in case of AWS) or GLB(in case of GKE) can be found by `kubectl get svc -n ingress-nginx` Only one service should have a public ip.
2. In order to test run the following,
	kubectl run echoheaders --image=gcr.io/google_containers/echoserver:1.4 --replicas=1 --port=8080\
	kubectl expose deployment echoheaders --port=80 --target-port=8080 --name=echoheaders-x\
	kubectl expose deployment echoheaders --port=80 --target-port=8080 --name=echoheaders-y\
	If cluster is on AWS: kubectl apply -f aws/ingress.yaml\ 
	If cluster is on GKE: kubectl apply -f gke/ingress.yaml\
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
    <pub-ip-lb>   foo.bar.com
    <pub-ip-lb>   bar.baz.com
    <pub-ip-lb>.  test.host.com
	```
	RUN `curl foo.bar.com\foo` :Should return the header\
	RUN `curl bar.baz.com\bar` :Should return the header\
    RUN `curl test.host.com`   :Should be redirected to default backend\   



Note:

1. FOR GKE: The user deploying these resources should be cluster admin. You can become cluster admin by `kubectl create clusterrolebinding myname-cluster-admin-binding --clusterrole=cluster-admin --user=<email-for-gcp>`
