# Prodcution Grade Elastic Search DB set up

Production Grade ES Set-Up with 2 Data Nodes, 2 Client Nodes and 3 Master Nodes. Each 
data node provisions and formats its own persistent volume. 

Setup:

1. kubectl -f es-data.yml 
2. kubectl -f es-client.yml
3. kubectl -f es-master.yml  

Test:

1. curl `http://<pub-ip-client-service>:9200/_cluster/health?pretty`


Note:

1. Data Nodes are deployed as a stateful set and thus need a headless svc to access them.
2. Client and Master nodes are deployed as stateless services. Client node service is exposed publicy or for the apps.
3. Headless service name for the master nodes is made available as an env variable (pre-set) to all the nodes so that they can find out the elected and eligible masters to form the cluster. 
4. Pod anti-affinity is enabled on all 3 services so that no 2 pods of same service are scheduled on the same node. 
5. The node-pool used for ES deployment should not be shared with a service which requires to tweak host kernel params. It is recommeded to have a seperate node pool for this service. Use NodeAffinity.