# Prodcution Grade Mongo DB set up

Production Grade Replicated Mongo Set-Up with 3 nodes. Each node provisions and formats its own persistent volume. 

Setup:

1. kubectl apply -f configure-node.yml   `This will configure the host machines kernel`
2. kubeclt apply -f mongo.yml `Creates namespace,sc,stateful set and headless service`

Test:

1. kubectl -n mongo exec -it mongo-0 -c mongo mongo
2. RUN rs.status()

Note:

1. A Cluster-binding role is already being created by the config. The role currently has admin permissions, however you can modify it to a viewer role only.
2. Please allocate resources to your mongo container as per you node limit and accordingly set wiredTiredcache size.
3. The sidecar container is very lightweight and only to configure replica set. In case of Scale-In and Scale-Out it makes sure that old nodes are removed from the replica set and new ones are added. 
4. Each cluster node can be accessed wih the dns name (which is persistent). For this set up the names will be 
	Node-0: mongo-0.mongo.mongo.svc.cluster.local:27017
	Node-1: mongo-1.mongo.mongo.svc.cluster.local:27017
	Node-2: mongo-2.mongo.mongo.svc.cluster.local:27017
5. The data on these nodes is persistent during pod restarts.
6. Pod Anti-affinity policy makes sure that no 2 pods are scheduled on same node. 
7. In-case the cluster scales new nodes are created in order and therefore dns names need not be changed in the app config.  



