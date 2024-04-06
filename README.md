# Deploy Production-ready WordPress and MariaDB on AWS Kubernetes.

Persistent storage is required to store very important data and avoiding total loss of data.
Kubernetes deals with pods that have short life span, they could be stopped at any time and restarted on a different node.
when this happens, container's filesystem is lost with the pod. this is not reliable hence the need for filesystem that is available and accessible irrespective of pod actions.

PV is configured to use different types of storage technology such as:
- CephFS
- iSCSI
- NFS
- Azure File

We will use Network File System (NFS) which is a way of sharing a centralised filesystem across multiple nodes. 
Although persistent storage is managed by kubernetes in the cluster, the actual storage is on nfs server which is not part of the kubernetes cluster and it is on different subnet.


## Persistent Volume
![](pv-snip)
Creating a PV within your cluster, tells Kubernetes that pods should have access to persistent storage that will outlive the pod and possibly the cluster itself!).
PVs can be created manually through kubectl or can be dynamically created by provisioners

PVs are not created within a namespace within your cluster and is therefore available to all pods within a cluster.

## Persistent Volume Claims
![](pvc-snip)

We want pods to access the PV created. To do this, a Persistent Volume Claim or PVC is required. 
When PVC is created within a namespace, only pods in that namespace can mount it. However, it can be bound to any PV as these are not namespaced.

It is possible that Kubernetes cannot bind the PVC to a valid PV and that the PVC remains unbound until a PV becomes available.
This will lead to instances of pods in 'Pending' state instead of 'Running' state and PVC having 'Unbound' status.

## Mounting PVC
![](mount-snip)

Here access to PVC in the pod is done by mounting the storage as a volume within the container.
Once PVC is mounted by the pod, the application within the Pod’s container(s) now have access to the persistent storage.

Upon reschedule of pod(s), it will be reconnected to the same PV and will have access to the data it was using before it died, even if this is on another node.


## Requirements

- Install [Terraform](https://developer.hashicorp.com/terraform/install)
- Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Generate key pair to connect to EC2 instances in AWS console. Name it 'terraform-key'. Choose 'RSA' key pair type and use .pem key file format. 
-----

# Getting Started

There are six sections to follow and implement as shown below:
- Provision AWS Infrastructure
- Set up Kubernetes cluster and NFS srver
- Create Dynamic Persistent Volume Provisioner
- Install Wordpress and MariaDB with Helm charts
- Connect to Wordpress and MariaDB
- Testing Data Persistence


-----

## Provision AWS Infrastructure

1. **Clone this repo to local machine**
   ```bash
   cd /
   git clone git@github.com:odennav/wordpress-mariadb-helm.git
   cd terraform-kubernetes-aws-ec2/terraform-manifest
   ```

2. **Provision AWS resources**

   Execute these terraform commands sequentially on your local machine to create the AWS infrastructure.

   ```bash
   cd terraform-manifest
   ```

   **Initializes terraform working directory**

   ```bash
   terraform init
   ```

   **Validate the syntax of the terraform configuration files**

   ```bash
   terraform validate
   ```

   **Create an execution plan that describes the changes terraform will make to the infrastructure.**

   ```bash
   terraform plan
   ```

   **Apply the changes described in execution plan**
   ```bash
   terraform apply -auto-approve
   ```
   Check AWS console for instances created and running

   ![ec2](c2instances-shot)


   **SSH Access**

   Use .pem key from AWS to SSH into the public EC2 instance.
   IPv4 address of public EC2 instance will be shown in terraform outputs.


   ```bash
   ssh -i private-key/terraform-key.pem ec2-user@<ipaddress>
   ```
   Its possible to use public EC2 instance as a jumpbox to securely SSH into private EC2 instances within the VPC.

3. **Change password of public ec2instance (control-dev) user**
   ```bash
   sudo passwd
   ```
   Switch to root user

   **Update apt package manager**
   ```bash
   cd /
   apt update -y
   apt upgrade -y
   ```

   **Confirm git was installed by terraform**
   ```bash
   git --version
   ```

   **Confirm terraform-key was transferred to public ec2instance by null provisioner**

   Please note if .pem key not found, copy it manually.
   Also key can be copied to another folder because it will be deleted if node is restarted or shutdown
   ```bash
   ls -la /tmp/terraform-key.pem
   cp /tmp/terraform-key.pem /
   ```

   **Change permissions of terraform-key.pem file**

   SSH test will fail if permissions of .pem key are not secure enough
   ```bash
   chmod 400 /tmp/terraform-key.pem
   ```


4. **Clone this repo to / directory in control-dev node**
   ```bash
   cd /
   git clone git@github.com:odennav/terraform-kubernetes-aws-ec2.git
   ```

   **Copy IPv4 adresses of private ec2instances deployed by terraform**

   Enter each ip address into ipaddr-list.txt.
   Don't change format seen in .txt file
   Ip addresses will be read by bash scripts.
   For security reasons, don't show your private ips. The ones below are destroyed.
   Picture shown below is just for clarity.

   ![](https://github.com/odennav/terraform-k8s-aws_ec2/blob/main/docs/ec2-private-ip.PNG)

-----

## Set up Kubernetes cluster and NFS server

1. **Install Ansible in devbuild**
   ```bash
   sudo apt install software-properties-common
   sudo add-apt-repository --yes --update ppa:ansible/ansible
   sudo apt install ansible
   ```

   **Using Ansible**
   The bootstrap and k8s directories in this repository contain the Ansible scripts necessary to set up your servers with the required packages and 
   applications.
   Edit values of aa, bb and cc with same values used in Vagrantfile.

2. **Bootstrap EC2 Private Instances**
   
   All nodes need to be bootstrapped.This process involves updating the OS, creating a non-root user, and setting up SSH to prevent remote login
   by the root user for security reasons.Once the bootstrap is complete, you will only be able to log in as odennav-admin.

   Confirm SSH access to k8snode1:   
   ```bash
   ssh -i /root/.ssh/id_rsa odennav-admin@<k8snode1-ip>
   ```  
   To return to devbuild, type "exit" and press "Enter" or use "Ctrl+D".
   
   Confirm SSH access to k8snode2:
   ```bash
   ssh -i /root/.ssh/id_rsa odennav-admin@<k8snode2-ip>
   ```  
  
   Now you can now bootstrap them:
   ```bash
   cd ../bootstrap
   ansible-playbook bootstrap.yml --limit k8s_master,k8s_node
   ```

   **Set up Kubernetes Cluster**

   Your kube nodes are now ready to have a Kubernetes cluster installed on them.
   Execute playbooks in this particular order:

   ```bash
   cd ../k8s
   ansible-playbook k8s.yml  --limit k8s_master
   ansible-playbook k8s.yml  --limit k8s_node
   ```

   Check status of your nodes and confirm they're ready
   ```bash
   kubectl get nodes
   ```


3. **Bootstrap the NFS Server**
   
   Bootstrap this server. This process updates the OS, creates a non-root user and sets up SSH such that the root user cannot log in remotely for
   security.
   Once the bootstrap is complete you will only be able to log in as odennav-admin

   ```bash
   cd ../ansible/bootstrap
   ansible-playbook bootstrap.yml --limit nfs_server
   ```

   **Create NFS share**

   ```bash
   cd ../nfs
   ansible-playbook nfs.yml
   ```
   /pv-share directory is created and made available to all nodes, but its not mounted yet by the nodes
   
   
4. **Login to 1st node in cluster**

   ```bash
   ssh -i /tmp/terraform-key.pem odennav-admin@<k8smaster-ip>
   ```

   **Confirm nfs client is installed** 
   ```bash
   dpkg -l | grep nfs-common
   ```

   If not available:
   ```bash
   sudo apt install nfs-common
   ```

5. **Create shared directory and mount nfs share**

   This directory will be mounted to /pv-share created in NFS server

   ```bash
   cd /
   sudo mkdir /shared
   sudo chmod 2770 /shared
   sudo mount -t nfs <nfsserver ip>:/pv-share /shared
   ```

6. **Confirm NFS share is implemented**

   Make a test file in /shared dir on the cluster node. It should be present in /pv-share dir on nfsserver.

   ```bash
   sudo touch test-k8smaster
   ```

   **Repeat process from step 4 to step 6 for other kubernetes nodes
   Exit out of k8smaster node into devbuild and repeat steps above.


-----

## Create Dynamic Persistent Volume Provisioner

1. **Login to k8smaster and Confirm Helm is installed**

   Helm is an effective package manager for kubernetes

   ```bash
   helm version
   ```
   ![](helm-version)


   If not installed
   ```bash
   sudo snap install helm --classic
   ```


2. **Confirm persistent volume provisioner installed**
   
   Helm should be installed, then add & install nfs-subdir-external-provisioner package.

   ```bash
   kubectl get all -n nfs-provisioner
   kubectl get sc -n nfs-provisioner
   ```
   This should show dynamic provisioner setup and ready

   ![](sc-snip)

   If pv provisioner not installed, do it manually:

   ```bash
   helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
   helm install -n nfs-provsioner --create-namespace nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=<k8smaster ip address> --set nfs.path=/pv-share
```

3. **Setup PVC for Wordpress**
   
   Our PV provisioner installed will dynamically provision PVs when PVCs are created.
   
   **Install kubectx**
   Kubectx is a tool to switch between clusters on kubectl faster.
   Once this is installed kubens will be available. kubens is used to switch between kubernetes namespaces.

   ```bash
   sudo snap install kubectx --classic
   ```

   Confirm kubens installed

   ```bash
   kubens --version
   ```
   ![](kubens-vs)

   **Create wordpress namespace**

   Assuming you've kubectl installed along with kubernetes cluster.

   ```bash
   kubectl create namespace wordpress
   kubens wordpress
   ```

   **Create PVC request on k8smaster**

   ```bash
   kubectl create -f wp-pvc.yaml
   ```

4. **Configure global Docker image parameters**

   **Configure Wordpress Parameters**

   Match this parameters and replace the values, so we have an account to access Wordpress:

   - **wordpressUsername
   - **wordpressPassword
   - **wordpressEmail
   - **wordpressFirstName
   - **wordpressLastName
   - **wordpressBlogName

   ```bash
   sed -i '/wordpressUsername: user/wordpressUsername: odennav/' values.yaml
   sed -i '/wordpressPassword: ""/wordpressPassword: odennav/' values.yaml
   sed -i '/wordpressEmail: user@example.com/wordpressEmail: contact@odennav.com/' values.yaml
   sed -i '/wordpressFirstName: FirstName/wordpressFirstName: odennav/' values.yaml
   sed -i '/wordpressLastName: LastName/wordpressLastName: odennav/' values.yaml
   sed -i '/wordpressBlogName: User's Blog!/wordpressBlogName: The Odennav Blog!/' values.yaml
   ```


   **Configure Persistence and Database Parameters**

   Enable persistence using persistence volume claims and peristence volume access modes.
   Match and replace values for persistence and database parameters below:

   - **persistence.storageClass
   - **persistence.existingClaim
   - **mariadb.primary.persistence.storageClass
   - **mariadb.auth.username
   - **mariadb.auth.password

   ```bash
   sed -i '/persistence:/,/volumePermissions:/ {/storageClass: ""/s/""/nfs-client}' values.yaml
   sed -i '/persistence:/,/volumePermissions:/ {/existingClaim: ""/s/""/pvc-wordpress}' values.yaml
   sed -i '/mariadb:/,/externalDatabase:/ {/storageClass: ""/s/storageClass/nfs-client}' values.yaml
   sed -i '/mariadb:/,/externalDatabase:/ {/username: bn_wordpress/s/bn_wordpress/odennav_wordpress}' values.yaml
   sed -i '/mariadb:/,/externalDatabase:/ {/password: ""/s/""/odennav}' values.yaml
   ```


   **Configure Replica Count**

   Number of Wordpress replicas to deploy
   - **replicaCount

   ```bash
   sed -i '/replicaCount: 1/replicaCount: 3/' values.yaml
   ```

   **Configure Auto Scaling**
   
   Enable horizontal scalability of pod resources for Wordpress when traffic load is increased

   - **autoscaling.enabled

   ```bash
   sed -i '/autoscaling:/,/metrics:/ {/enabled: false/s/"false"/true}' values.yaml
   ```

-----

## Install Wordpress and MariaDB with Helm chart

1. **Install Wordpress and MariaDB**

   Use Helm charts to bootstrap wordpress and mariadb deployment on kubernetes cluster.

   ```bash
   helm repo update
   ```

   Install the chart with release-name, my-wordpress

   ```bash
   helm install -f values.yml my-wordpress oci://registry-1.docker.io/bitnamicharts/wordpress
   ```

   After installation, instructions will be printed to stdout as shown below:

   ![]()


2. **Add Wordpress Secrets**
   
   We'll add wordpress credentials as a kubernetes secret.
   From stdout above, Export the wordpress password to environment variable, WORDPRESS_PASSWORD

   ```bash
   export WORDPRESS_PASSWORD=$(kubectl get secret --namespace wordpress my-wordpress -o jsonpath="{.data.wordpress-password}" | base64 -d)
   ```

   Then create secret:

   ```bash
   kubectl create secret generic db-user-pass \
   --from-literal=username=wordpress \
   --from-literal=password=$WORDPRESS_PASSWORD
   ```

   Delete environment variable, to prevent non-admin users viewing it's value.

   ```bash
   unset WORDPRESS_PASSWORD
   ```
-----

## Connect to Wordpress and MariaDB

1. **Confirm PVCs are bound**

   This confirms the applications installed will have access to persistent storage

   ```bash
   kubectl get pvc -n wordpress
   ```
   ![](get-pvc)

2. **Check service created**

   ```bash
   kubectl get svc -n wordpress
   ```

   ![](get-svc)


3. **Pull HTML data from wordpress pods** 

   Export IPv4 address and port

   ```bash
   export NODE_PORT=$(kubectl get --namespace wordpress -o jsonpath="{.spec.ports[0].nodePort}" services my-wordpress)
   export NODE_IP=$(kubectl get nodes --namespace wordpress -o jsonpath="{.items[0].status.addresses[0].address}")
   echo "WordPress URL: http://$NODE_IP:$NODE_PORT/"
   echo "WordPress Admin URL: http://$NODE_IP:$NODE_PORT/admin"
   ```

   Make connection to Wordpress site
   ```bash
   curl http://$NODE_IP:$NODE_PORT/
   ```

   ![](curl-snip)

4. **Service - Host port forwarding**

   Set up a port forward from the Service to the host on the master node.

   ```bash
   kubectl port-forward — namespace wordpress
   ```

5. **Host - Local port forwarding**

   Set up a port forward from the host machine to the development machine.

   ```bash
   ssh -L 54321:localhost:5432 k8smaster@<k8smaster ip address> -i /tmp/terraform-key.pem
   ```

-----

## Testing Data Persistence

1. **Check pods running**
   
   Confirm mariadb pods are in 'Ready' state

   ```bash
   kubectl get pods -n wordpress
   ```

   ![](get-pods)

2. **Delete pods**

   ```bash
   kubectl delete pod <pod name> -n wordpress
   ```

3. **Restart port forwards**
   ```bash
   kubectl port-forward — namespace wordpress
   ssh -L 54321:localhost:5432 k8smaster@<k8smaster ip address> -i ~/.ssh/id_rsa
   ```

   Upon deletion of pod, another instance is automatically scheduled.
   You'll still be able to access your database with data still intact.

-----

##  Removing Wordpress and MariaDB
   If you're taking the option to remove both applications, implement the following:

1. **Delete PVC**
   This removes and unbounds PVC from PV.

   ```bash
   kubectl delete -f pg-pvc.yml 
   ```

2. **Delete namespace**

   ```bash
   kubectl delete ns wordpress
   ```



Enjoy!   
