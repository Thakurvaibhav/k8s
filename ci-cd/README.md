# Halyard Kubernetes manifests which can be used to manage production grade spinnaker installations

## Setup: 

### Halyard Setup

1. Create spinnaker namespace: `kubectl create ns spinnaker`

2. Create AWS Secret for the backup job: `kubectl create secret generic spinnaker-aws --from-literal="aws_access_key_id=<AWS_ACCESS_KEY_ID>" --from-literal="aws_secret_access_key=<AWS_SECRET_ACCESS_KEY>"`

3. Install Halyard using helm: `helm upgrade --install <RELEASE_NAME> spinnaker/`

### Spinnaker Setup: [ Install Spinnaker in a Kubernetes cluster, add other kubernetes clusters (if any), Enable Jenkins as trigger ]

1. Exec into the halyard pod: `kubectl -n spinnaker exec -it <HALYARD_POD_NAME> /bin/bash` and `su - spinnaker`
2. Configure kubectl access to home cluster
	- `kubectl config set-cluster default --server=https://kubernetes.default --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
	- `kubectl config set-context default --cluster=default`
	- `token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)`
	- `kubectl config set-credentials user --token=$token`
	- `kubectl config set-context default --user=spinnaker`
	- `kubectl config use-context default`
	- Alternatively, you can place the kubeconfig at ~/.kube/config and use it directly
3. Check if hal is up: `hal version list`
4. Add AWS S3 as persistent storage for kubernetes:
	- `hal config storage s3 edit --bucket <BUCKET_NAME> --access-key-id <ACCESS_KEY_ID> --secret-access-key --region us-west-2`
	- `hal config storage edit --type s3`
5. Enter the AWS SECRET KEY when prompted
6. Configure kubectl to access your kubernetes installation.
7. Add kubernetes account to spinnaker:
    - `CONTEXT=$(kubectl config current-context)`
    - `kubectl apply --context $CONTEXT -f https://spinnaker.io/downloads/kubernetes/service-account.yml`
    - `TOKEN=$(kubectl get secret --context $CONTEXT $(kubectl get serviceaccount spinnaker-service-account --context $CONTEXT -n spinnaker -o jsonpath='{.secrets[0].name}') -n spinnaker -o jsonpath='{.data.token}' | base64 --decode)`
    - `kubectl config set-credentials ${CONTEXT}-token-user --token $TOKEN`
    - `kubectl config set-context $CONTEXT --user ${CONTEXT}-token-user`
    - `hal config provider kubernetes enable`
    - `hal config provider kubernetes account ​<KUBERNETES_ACCOUNT_NAME> --context $(kubectl config current-context)`
    - `hal config features edit --artifacts-rewrite true`
8. In order to add more than one kubernetes account to your spinnaker installation,
	- Make sure you have kubectl access to that cluster and context is set correctly
	- Repeat Step 7
9. Choose destination kubernetes account to install spinnaker
	- `ACCOUNT=​<KUBERNETES_ACCOUNT_NAME>` , make sure this account has been added to spinnaker
	- `hal config deploy edit --type distributed --account-name $ACCOUNT`
	- `hal version list`, choose the version of spinnaker you want to install
	- `VERSION=<CHOSEN_VERSION>`
	- `hal config version edit --version $VERSION`
	- `hal deploy apply`
10. Add Jenkins as trigger for spinnaker.
	- `hal config ci jenkins enable`
	- `hal config ci jenkins master add <JENKINS_MASTER_NAME> --address http://<JENKINS_HOST>:<JENKINS_PORT> --username <JENKINS_USER> --password`
	- Enter the API key for `<JENKINS_USER>` when prompted
11. Expose Spinnaker for your users:
	- Make sure you are an Internal/External ingress controller deployed. In case of external ingress it is highly recommended to enable OAuth. 
	- In the cluster where you have installed spinnaker, deploy the ingress object. Make sure you edit the ingress object's hostname as per your preference. 
	- `kubectl apply -f spinnaker-halyard/spinnaker-ingress.yaml`
12. Update endpoints in the hal config:
	- Exec into the halyard pod: `kubectl -n spinnaker exec -it <POD_NAME> /bin/bash`
	- Run commands as spinnaker user: `su - spinnaker`
	- `hal config security ui edit --override-base-url ​http://spinnaker.<YOUR_ORG>.com`
	- `hal config security api edit --override-base-url http://spingate.<YOUR_ORG>.com`
	- `hal deploy apply`
	- Spinnaker should now be accessible at `http://spinnaker.<YOUR_ORG>.com`

## Add-Ons

1. Add Slack Notifications
2. Enable Travis as Pipeline Trigger
	- `hal config ci travis master add infra --address https://api.travis-ci.com --base-url https://travis-ci.com --github-token --number-of-repositories 250`
	- Enter the Personal access token when prompted
	- The github user for which the Personal access token has been generated should have `read:org, repo, user` permissions. 
3. Enable Google Auth


## Back-up and Restore

1. The halyard backup cron will create daily backups of hal configuration and store it over an EBS volume. 
2. In order to create manual backups.
	- Exec into the halyard pod: `kubectl -n spinnaker exec -it <POD_NAME> /bin/bash`
	- Run commands as spinnaker user: `su - spinnaker`
	- Create backup: `hal backup create`
3. In order to restore a backup
	- Exec into the halyard pod: `kubectl -n spinnaker exec -it <POD_NAME> /bin/bash`
	- Run commands as spinnaker user: `su - spinnaker`
	- Restore backup: `hal backup restore -q --backup-path <NAME_OF_BACKUP_FILE>`


NOTE: This installtion is guide has basic settings like adding Kubernetes accounts and Jenkins as Trigger. We can make tons of other customizations like Slack Notifications, Docker registry accounts etc. Please refer to official Spinnaker documentation  `https://www.spinnaker.io/setup/` for it. 

