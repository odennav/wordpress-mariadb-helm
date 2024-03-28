# Wordpress Installation with MariaDB on Kubernetes Cluster.

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


# Getting Started

We created three nodes(k8smaster, k8snode1 and k8snode2) and installed a kubernetes cluster in this repo here.
This is follows up on that and extends the cluster by adding persistent storage.

Name of our NFS server  is nfsserver, config build added to vagrant file.
We'll provision a new node, and bootstrap this server.
This process updates the OS, creates a non-root user and sets up SSH such that the root user cannot log in remotely for security.
Once the bootstrap is complete you will only be able to log in as server-admin

1. Provision VMs
Start all nfsserver node and along with other nodes in cluster

```bash
vagrant up
```

2. Setting up the nfsserver

```bash
cd ../ansible/bootstrap
ansible-playbook bootstrap.yml --limit nfs_server
```

3. Create NFS share

```bash
cd ../nfs
ansible-playbook nfs.yml
```
/pv-share directory is created and made available to all nodes, but its not mounted yet by the nodes
In the exports file, the root_squash prevents the NFS server from allowing the root user on the NFS client machine from having root-level access to files on the NFS share.

4. Login to k8smaster node
Recall from previous repo here, you can only access k8smaster node from devbuild after it was bootstrapped.

vagrant ssh devbuild

Then SSH to k8smaster
ssh -i /root/.ssh/id_rsa odennav-admin@<k8smaster ip>

5. Confirm nfs client is installed 
```bash
dpkg -l | grep nfs-common
```

If not available:
```bash
sudo apt install nfs-common
```

6. Create shared directory and mount nfs share
This diectory will be mounted to /pv-share created in NFS server

```bash
cd /
sudo mkdir /shared
sudo chmod 2770 /shared
sudo mount -t nfs <nfsserver ip>:/pv-share /shared
```

7. Confirm nfs share is implemented
Make a test file in /shared dir on k8smaster. It should be present in /pv-share dir on nfsserver.

```bash
sudo touch test-k8smaster
```

8. Repeat process from step 4 to step 7 for other k8snodes
Exit out of k8smaster node into devbuild and repeat steps above.

```bash
Ctrl+D
```

## Creating PV 

1. Confirm Helm is installed
Helm is an effective package manager for kubernetes

```bash
helm version
```
![](helm-version)


If not installed
```bash
sudo snap install helm --classic
```


2. Confirm persistent volume provisioner installed
Assuming you implemented instructions in this repo here, helm should be installed and used to add & install nfs-subdir-external-provisioner in nfs-provisioner.

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

## Creating PVC for Wordpress
Our PV provisioner installed will dynamically provision PVs when PVCs are created.
We'll now create PVC for wordpress application.

1. Install kubectx
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

2. Create and switch to wordpress namespace
Assuming you've kubectl installed along with kubernetes cluster.

```bash
kubectl create namespace wordpress
kubens wordpress
```

3. On k8smaster apply manifest file, wp-pvc.yml 
   Manifest file found in wp-manifest folder and ensure namespace used is wordpress.


```bash
kubectl create -f wp-pvc.yml
```

4. Update helm repo

```bash
helm repo update
```

4b. Configure parameters in values.yaml manifest file
Add the following values for persistence and database parameters below:

persistence.storageClass="nfs-client"
persistence.existingClaim="my-release-wordpress"

mariadb.primary.persistence.storageClass="nfs-client"

You can alter the persistence size based on availabel resources and prefrence.

Upon opening values.yaml file, you'll find a lot of content.
Use stream editor to insert values for parameters:

```bash
cd /k8s-wordpress-mariadb/manifest/
sed -i 's/existingClaim=""/existingClaim="my-release-wordpress/g' values.yaml
sed -i 's/storageClass: ""/storageClass: "nfs-client"/g' values.yaml
```

5. Install Wordpress and MariaDB
Use Helm charts to bootstrap wordpress and mariadb deployment on kubernetes cluster.

Install the chart with release-name, my-wordpress

```bash
helm install -f values.yml my-wordpress oci://registry-1.docker.io/bitnamicharts/wordpress
```

After installation, instructions will be printed to stdout as shown below:

![]()


6. Add Wordpress Secrets
We'll add wordpress credentials as a kubernetes secret.

From stdout above, Export the wordpress password to environment variable, WORDPRESS_PASSWORD

```bash
export WORDPRESS_PASSWORD=$(kubectl get secret --namespace wordpress postgres-postgresql -o jsonpath="{.data.wordpress-password}" | base64 -d)
```

Then create secret:

```bash
kubectl create secret generic db-user-pass \
--from-literal=username=wordpress \
--from-literal=password=$WORDPRESS_PASSWORD
```

Delete environment variable

```bash
unset WORDPRESS_PASSWORD
```

## Connect to Wordpress and MariaDB

1. Confirm PVCs are bound
This confirms the applications installed will have access to persistent storage

```bash
kubectl get pvc -n wordpress
```
![](get-pvc)

2. Check service created

```bash
kubectl get svc -n wordpress
```

![](get-svc)


3. Pull HTML data from wordpress sample page 
Use curl command on ip address of any k8snode and port number provided by service

```bash
curl <k8smaster>:port-number
```

![](curl-snip)

4. Set up a port forward from the Service to the host on the master node.

```bash
kubectl port-forward — namespace wordpress
```

5. Set up a port forward from the host machine to the development machine.

```bash
ssh -L 54321:localhost:5432 k8smaster@<k8smaster ip address> -i ~/.ssh/id_rsa
```


If you can connect, you have successfully installed a database using a Kubernetes PV



## Testing Data Persistence

1. Check pods running:
Confirm mariadb pods are in 'Ready' state

```bash
kubectl get pods -n wordpress
```

![](get-pods)

2. Delete pods:

```bash
kubectl delete pod <pod name> -n wordpress
```

3. Restart port forwards
```bash
kubectl port-forward — namespace wordpress
ssh -L 54321:localhost:5432 k8smaster@<k8smaster ip address> -i ~/.ssh/id_rsa
```

Upon deletion of pod, another instance is automatically scheduled.
You'll still be able to access your database with data still intact.


# Removing Wordpress and MariaDB
If you're taking the option to remove both applications, implement the following:

1. Delete PVC
This removes and unbounds PVC from PV.

```bash
kubectl delete -f pg-pvc.yml 
```

2. Delete namespace

```bash
kubectl delete ns wordpress
```



Enjoy!   
