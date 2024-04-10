# Deploy Production-ready WordPress and MariaDB on AWS Kubernetes.

Persistent storage is required to store very important data and avoiding total loss of data.
Kubernetes deals with pods that have short life span, they could be stopped at any time and restarted on a different node.
causing the container's filesystem to be lost with the pod. This is not reliable, hence the need for filesystem that is available and accessible irrespective of pod actions.

PV is configured to use different types of storage technology such as:
- CephFS
- iSCSI
- NFS
- Azure File

We will use Network File System (NFS) which is a way of sharing a centralised filesystem across multiple nodes. 
Although persistent storage is managed by kubernetes in the cluster, the actual storage is on nfs server which is not part of the kubernetes cluster and it is on different subnet.

![](https://github.com/odennav/wordpress-mariadb-helm/blob/main/docs/1.png)

### Persistent Volume

Creating a PV within your cluster, tells Kubernetes that pods should have access to persistent storage that will outlive the pod and possibly the cluster itself!).
PVs can be created manually through kubectl or can be dynamically created by provisioners
PVs are not created within a namespace within your cluster and is therefore available to all pods within a cluster.

### Persistent Volume Claims

We want pods to access the PV created. To do this, a Persistent Volume Claim or PVC is required. 
When PVC is created within a namespace, only pods in that namespace can mount it. However, it can be bound to any PV as these are not namespaced.
It is possible that Kubernetes cannot bind the PVC to a valid PV and that the PVC remains unbound until a PV becomes available.
This will lead to instances of pods in 'Pending' state instead of 'Running' state and PVC having 'Unbound' status.

### Mounting PVC

Here access to PVC in the pod is done by mounting the storage as a volume within the container.
Once PVC is mounted by the pod, the application within the Pod’s container(s) now have access to the persistent storage.
Upon reschedule of pod(s), it will be reconnected to the same PV and will have access to the data it was using before it died, even if this is on another node.


### Prerequisites

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
- Securing Traffic with Let's Encrypt Certificates
- Enable WordPress monitoring metrics

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

   ```console
   cd terraform-manifest
   ```

   **Initializes terraform working directory**

   ```console
   terraform init
   ```

   **Validate the syntax of the terraform configuration files**

   ```console
   terraform validate
   ```

   **Create an execution plan that describes the changes terraform will make to the infrastructure.**

   ```console
   terraform plan
   ```

   **Apply the changes described in execution plan**
   ```console
   terraform apply -auto-approve
   ```
   Check AWS console for instances created and running



   **SSH Access**

   Use .pem key from AWS to SSH into the public EC2 instance.
   IPv4 address of public EC2 instance will be shown in terraform outputs.


   ```bash
   ssh -i private-key/terraform-key.pem ec2-user@<ipaddress>
   ```
   Its possible to use public EC2 instance as a jumpbox to securely SSH into private EC2 instances within the VPC.

3. **Change password of root user for public EC2instance (control-dev)**

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


-----

## Set up Kubernetes Cluster and NFS Server

1. **Install Ansible in devbuild**
   ```bash
   sudo apt install software-properties-common
   sudo add-apt-repository --yes --update ppa:ansible/ansible
   sudo apt install ansible
   ```

   **Using Ansible**
   
   The bootstrap and k8s directories in this repository contain the Ansible scripts necessary to set up your servers with the required packages and 
   applications.
   
   Open the inventory file and edit values of aa, bb and cc.
   
   Identify IPv4 addresses of private EC2 instances.

   Insert them for k8snode-1 under `k8s_master` group, k8snode-2 and k8snode-3 under `k8s_node` group and db-1 under `nfs_server` group.

2. **Bootstrap EC2 Private Instances**
   
   All nodes need to be bootstrapped.This process involves updating the OS, creating a non-root user, and setting up SSH to prevent remote login
   by the root user for security reasons. Once the bootstrap is complete, you will only be able to log in as odennav-admin.

   Confirm SSH access to k8snode1:   
   ```bash
   ssh -i /tmp/terraform-key.pem  odennav-admin@<k8snode-1 ipv4 address>
   ```  
   To return to devbuild, type `exit` and press `Enter` or use `Ctrl+D`.
   
   Confirm SSH access to k8snode-2:
   ```bash
   ssh -i /tmp/terraform-key.pem  odennav-admin@<k8snode-2 ipv4 address>
   ```  
  
   Confirm SSH access to k8snode-3:
   ```bash
   ssh -i /tmp/terraform-key.pem odennav-admin@<k8snode-3 ipv4 address>
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
   ```console
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
   ssh -i /tmp/terraform-key.pem odennav-admin@<k8snode-1 ipv4 address>
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
   sudo mount -t nfs <db-1 ipv4 address>:/pv-share /shared
   ```

6. **Confirm NFS share is implemented**

   Make a test file in /shared dir on the cluster node. It should be present in /pv-share dir on nfsserver.

   ```bash
   sudo touch test-k8smaster
   ```

   `Repeat process from step 4 to step 6 for other kubernetes nodes
   Exit out of k8smaster node into devbuild and repeat steps above.`


-----

## Create Dynamic Persistent Volume Provisioner

1. **Login to k8smaster and Confirm Helm is installed**

   Helm is an effective package manager for kubernetes

   ```conosle
   helm version
   ```

   If not installed
   ```bash
   sudo snap install helm --classic
   ```


2. **Confirm persistent volume provisioner installed**
   
   Helm should be installed, then add & install nfs-subdir-external-provisioner package.

   ```console
   kubectl get all -n nfs-provisioner
   kubectl get sc -n nfs-provisioner
   ```
   This should show dynamic provisioner setup and ready.

   If pv provisioner not installed, do it manually:

   ```console
   helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
   helm install -n nfs-provsioner --create-namespace nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=<db-1 ipv4 address> --set nfs.path=/pv-share
   ```


3. **Setup PVC for Wordpress**
   
   Our PV provisioner installed will dynamically provision PVs when PVCs are created.
   We'll use kubens to switch between kubernetes namespaces.

   ```bash
   sudo snap install kubectx --classic
   kubens --version
   ```

   **Create wordpress namespace**

   Assuming you've kubectl installed along with kubernetes cluster.

   ```console
   kubectl create namespace wordpress
   kubens wordpress
   ```

   **Create PVC request on k8smaster**

   ```console
   kubectl create -f wp-pvc.yaml
   ```

4. **Configure global Docker image parameters**

   Configure Wordpress Parameters
   Match this parameters and replace the values, so we have an account to access Wordpress:

   *wordpressUsername*
   
   *wordpressPassword*
   
   *wordpressEmail*
   
   *wordpressFirstName*
   
   *wordpressLastName*
   
   *wordpressBlogName*

   *wordpressScheme*


   ```bash
   sed -i '/wordpressUsername: user/wordpressUsername: odennav/' values.yaml
   sed -i '/wordpressPassword: ""/wordpressPassword: odennav/' values.yaml
   sed -i '/wordpressEmail: user@example.com/wordpressEmail: contact@odennav.com/' values.yaml
   sed -i '/wordpressFirstName: FirstName/wordpressFirstName: odennav/' values.yaml
   sed -i '/wordpressLastName: LastName/wordpressLastName: odennav/' values.yaml
   sed -i '/wordpressBlogName: User's Blog!/wordpressBlogName: The Odennav Blog!/' values.yaml
   sed -i '/wordpressScheme: http/wordpressScheme: https/' values.yaml
   ```


   **Configure Persistence and Database Parameters**

   Enable persistence using persistence volume claims and peristence volume access modes.
   Match and replace values for persistence and database parameters below:

   *persistence.storageClass*
   
   *persistence.existingClaim*
   
   *mariadb.primary.persistence.storageClass*
   
   *mariadb.auth.username*
   
   *mariadb.auth.password*

   ```bash
   sed -i '/persistence:/,/volumePermissions:/ {/storageClass: ""/s/""/nfs-client}' values.yaml
   sed -i '/persistence:/,/volumePermissions:/ {/existingClaim: ""/s/""/pvc-wordpress}' values.yaml
   
   sed -i '/mariadb:/,/externalDatabase:/ {/storageClass: ""/s/storageClass/nfs-client}' values.yaml
   sed -i '/mariadb:/,/externalDatabase:/ {/username: bn_wordpress/s/bn_wordpress/odennav_wordpress}' values.yaml
   sed -i '/mariadb:/,/externalDatabase:/ {/password: ""/s/""/odennav}' values.yaml
   ```

   **Configure PVC Access Modes**
   
   To access the /admin portal and enable WordPress scalability, a ReadWriteMany Persistent Volume Claim (PVC) is required.
      
      *persistence.accessModes*
      
      *persistence.accessMode*

   ```bash
   sed -i 's/ReadWriteOnce/ReadWriteMany/g' values.yaml
   ```

   **Configure Replica Count**

   Number of Wordpress replicas to deploy
   
   *replicaCount*

   ```bash
   sed -i '/replicaCount: 1/replicaCount: 3/' values.yaml
   ```

   **Configure Auto Scaling**
   
   Enable horizontal scalability of pod resources for Wordpress when traffic load is increased

   *autoscaling.enabled*

   ```bash
   sed -i '/autoscaling:/,/metrics:/ {/enabled: false/s/"false"/true}' values.yaml
   ```

   **Configure htaccess**
   
   For performance and security reasons, configure Apache with AllowOverride None and prohibit overriding directives with htaccess files
   

   *allowOverrideNone*

   ```bash
   sed -i '/allowOverrideNone: false/allowOverrideNone: true/' values.yaml
   ```

-----

## Install Wordpress and MariaDB with Helm chart

1. **Install Wordpress and MariaDB**

   Use Helm charts to bootstrap wordpress and mariadb deployment on kubernetes cluster.

   ```console
   helm repo update
   ```

   Install the chart with release-name, my-wordpress

   ```console
   helm install -f values.yml my-wordpress oci://registry-1.docker.io/bitnamicharts/wordpress
   ```

   After installation, instructions will be printed to stdout.


2. **Add Wordpress Secrets**
   
   We'll add wordpress credentials as a kubernetes secret.
   From stdout above, Export the wordpress password to environment variable, WORDPRESS_PASSWORD

   ```bash
   export WORDPRESS_PASSWORD=$(kubectl get secret --namespace wordpress my-wordpress -o jsonpath="{.data.wordpress-password}" | base64 -d)
   ```

   Then create secret:

   ```console
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

   ```console
   kubectl get pvc -n wordpress
   ```


2. **Check service created**

   ```console
   kubectl get svc -n wordpress
   ```


3. **HTTP access to Wordpress pods** 

   Export IPv4 address and port

   ```bash
   export NODE_PORT=$(kubectl get --namespace wordpress -o jsonpath="{.spec.ports[0].nodePort}" services my-wordpress)
   export NODE_IP=$(kubectl get nodes --namespace wordpress -o jsonpath="{.items[0].status.addresses[0].address}")
   echo "WordPress URL: http://$NODE_IP:$NODE_PORT/"
   echo "WordPress Admin URL: http://$NODE_IP:$NODE_PORT/admin"
   ```

   HTTP request to Wordpress site
   ```bash
   curl http://$NODE_IP:$NODE_PORT/
   ```


4. **Service - Host port forwarding**

   Set up a port forward from the Service to the host on the master node.

   ```console
   kubectl port-forward — namespace wordpress
   ```

5. **Host - Local port forwarding**

   Set up a port forward from the host machine to the development machine.

   ```bash
   ssh -L 54321:localhost:5432 k8snode-1@<k8snode-1 ipv4-address> -i /tmp/terraform-key.pem
   ```

----

## Test Data Persistence

1. **Check pods running**
   
   Confirm mariadb pods are in 'Ready' state

   ```console
   kubectl get pods -n wordpress
   ```

2. **Delete pods**

   ```console
   kubectl delete pod <pod name> -n wordpress
   ```

3. **Restart port forwards**
   ```console
   kubectl port-forward — namespace wordpress
   ssh -L 54321:localhost:5432 k8snode-1@<k8snode-1 ipv4-address> -i ~/.ssh/id_rsa
   ```

   Upon deletion of pod, another instance is automatically scheduled.
   You'll still be able to access your database with data still intact.


-----

## Secure Traffic with Let's Encrypt Certificates

The Bitnami WordPress Helm chart includes native support for Ingress routes and certificate management via cert-manager. This simplifies TLS configuration by enabling the use of certificates from various providers, such as Let's Encrypt.

### Install the Nginx Ingress Controller with Helm

Create namespace for ingress controller
Then switch to ingress-nginx namespace

```console
kubectl create namespace ingress-nginx
kubens ingress-nginx
```

Pull the chart sources:

```console
helm pull oci://ghcr.io/nginxinc/charts/nginx-ingress --untar --version 1.2.0
```

Change working directory to nginx-ingress:

```shell
cd nginx-ingress
```

Upgrade the CRDs:

```console
kubectl apply -f crds/
```

Install the chart with the release name, ingress-nginx

```console
helm install ingress-nginx .
```

Next, check if the Helm installation was successful by running command below:

```console
helm ls -n ingress-nginx
```


### Configure DNS for Nginx Ingress Controller

Configure `DNS` with a `domain` that you own and create the domain `A` record for the wordpress site.

Next, you will add the required `A` record for the wordpress application.

Please note, you need to identify the load balancer `external IP` created by the `nginx` deployment:


```console
kubectl get svc -n ingress-nginx
```

### Install Cert-Manager

First, add the `jetstack` Helm repo, and list the available charts:

```console
helm repo add jetstack https://charts.jetstack.io

helm repo update jetstack
```

Next, install Cert-Manager using Helm:

```console
helm install cert-manager jetstack/cert-manager --version 1.8.0 \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

Finally, check if Cert-Manager installation was successful by running below command:

```console
helm ls -n cert-manager
```

The output looks similar to `STATUS` column should print `deployed`:

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
cert-manager    cert-manager    1               2024-04-08 18:02:08.124264 +0300 EEST   deployed        cert-manager-v1.15.0     v1.15.0
```


### Configure Production Ready TLS Certificates for WordPress

A cluster issuer is required first, in order to obtain the final TLS certificate. Open and inspect the `cluster-manifest/letsencrypt-issuer-values.yaml` file provided in this repository:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: wordpress
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email:  <YOUR-EMAIL-HERE>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource used to store the account's private key.
      name: prod-issuer-account-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply via kubectl:

```console
cd wordpress-mariadb-helm/
kubectl apply -f cluster-manifest/letsencrypt-issuer-values.yaml
```

To secure WordPress traffic, open the helm `values.yaml` file in cluster-manifest/, and add the following settings:

```yaml
# Enable ingress record generation for WordPress
ingress:
  enabled: true
  certManager: true
  tls: false
  hostname: <YOUR_WORDPRESS_DOMAIN_HERE>
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  extraTls:
  - hosts:
      - <YOUR_WORDPRESS_DOMAIN_HERE>
    secretName: wordpress.local-tls
```

Upgrade via `helm`:

```console
helm upgrade wordpress bitnami/wordpress \
    --namespace wordpress \
    --version 22.0.0 \
    --timeout 10m0s \
    --values /wordpress-mariadb-helm/cluster-manifest/values.yaml
```

This automatically creates a certificate through cert-manager. You can then verify that you've successfully obtained the certificate by running the following command:

```console
kubectl get certificate -n wordpress wordpress.local-tls
```

If successful, the output's READY column reads True:

```text
NAME                  READY   SECRET                AGE
wordpress.local-tls   True    wordpress.local-tls   24h
```

Now, you can access WordPress using the domain configured earlier. You will be guided through the `installation` process.

## Enable WordPress Monitoring Metrics

In this section, you will learn how to enable metrics for monitoring your WordPress instance.

First, open the `wordpress-values.yaml` created earlier in this tutorial, and set `metrics.enabled` field to `true`:

```yaml
# Prometheus Exporter / Metrics configuration
metrics:
  enabled: true
```

Apply changes using Helm:

```console
helm upgrade wordpress bitnami/wordpress \
    --create-namespace \
    --namespace wordpress \
    --version 22.0.0 \
    --timeout 10m0s \
    --values /wordpress-mariadb-helm/cluster-manifest/values.yaml
```

Next, port-forward the wordpress service to inspect the available metrics:

```console
kubectl port-forward --namespace wordpress svc/wordpress-metrics 9150:9150
```

Now, open a web browser and navigate to [localhost:9150/metrics](http://127.0.0.1:9150/metrics), to see all WordPress metrics.

Finally, you need to configure Grafana and Prometheus to visualise metrics exposed by your new WordPress instance.


### Configuring WordPress Plugins

Plugins serve as the foundational components of your WordPress site, enabling crucial functionalities ranging from contact forms and SEO enhancements to site speed optimization, online store creation, and email opt-ins. Whatever your website requirements may be, plugins provide the necessary tools to fulfill them.

Here is a curated list of recommended plugins:

- [LiteSpeed Cache](https://wordpress.org/plugins/litespeed-cache/):  is a comprehensive site acceleration tool, offering an exclusive server-level cache and a suite of optimization features to enhance website performance.

- [Contact Form by WPForms](https://wordpress.org/plugins/wpforms-lite/): enables you to design visually appealing contact forms, feedback forms, subscription forms, payment forms, and various other types of forms for your website.

- [MonsterInsights](https://wordpress.org/plugins/google-analytics-for-wordpress/): is regarded as the premier Google Analytics solution for WordPress. It facilitates seamless integration between your website and Google Analytics, providing detailed insights into how visitors discover and interact with your site.

- [Query Monitor](https://wordpress.org/plugins/query-monitor/): serves as a developer tools panel for WordPress. It allows for debugging of database queries, PHP errors, hooks, and actions.

- [All in One SEO](https://wordpress.org/plugins/all-in-one-seo-pack/): aids in driving more traffic from search engines to your website. While WordPress is inherently SEO-friendly, this plugin empowers you to further enhance your website traffic by implementing SEO best practices.

- [SeedProd](https://wordpress.org/plugins/coming-soon/): This plugin stands out as the premier drag-and-drop page builder for WordPress. It simplifies the process of customizing your website design and crafting unique page layouts effortlessly, eliminating the need for manual code writing.

- [UpdraftPlus](https://wordpress.org/plugins/updraftplus/): Facilitates backups and restoration. Backup your files and database backups into the cloud and restore with a single click.

For more plugins, visit <https://wordpress.org/plugins/> 


### Enhancing Wordpress Performance

Content Delivery Network (CDN) is a straightforward method to accelerate a WordPress website. A CDN consists of servers strategically positioned to optimize the delivery of media files, thereby enhancing the loading speed of web pages. Many websites encounter latency issues when their visitors are located far from the server location. By utilizing a CDN, content delivery can be expedited by relieving the web server of the task of serving static content such as images, CSS, JavaScript, and video streams. Additionally, caching static content minimizes latency. Overall, CDN serves as a dependable and effective solution for optimizing websites and enhancing the global user experience.


### Configuring Cloudflare

[Cloudflare](https://www.cloudflare.com/en-gb/) is a renowned provider of content delivery network (CDN), DNS, DDoS protection, and security services. Leveraging Cloudflare can significantly accelerate and bolster the security of your WordPress site, making it an excellent solution for website optimization and protection.

Cloudflare account is required for this configuration. Visit the [Cloudflare website](https://www.cloudflare.com/en-gb/) and signup for a free account.

Below are the steps to configure Cloudflare for your WordPress site:

1. Log in to the Cloudflare dashboard using your account credentials and click on the `+ Add Site` button.
2. Enter your WordPress site's domain and click `Add Site`.
3. Choose the `Free` plan and click `Get Started`.
4. From `Review DNS records` and click `Add record`. Add an `A` record with your desired name and the `IPv4 address` of your cloud provider load balancer. Click `Continue`.
5. Follow instructions to change your domain registrar's nameservers to Cloudflare's nameservers.
6. After updating nameservers, click `Done, check nameservers`.
7. Cloudflare may offer configuration recommendations; you can skip these for now by clicking `Skip recommendations`.

An email will confirm when your site is active on Cloudflare.
Use the Analytics page in your Cloudflare account to monitor web traffic on your WordPress site.


-----

###  Remove Wordpress and MariaDB
   If you're taking the option to remove both applications, implement the following:

1. **Delete PVC**
   
   This removes and unbounds PVC from PV.

   ```console
   kubectl delete -f pg-pvc.yml 
   ```

2. **Delete Namespaces**

   ```console
   kubectl delete ns wordpress
   kubectl delete ns ingress-nginx
   ```

3. **Destroy AWS resources**

   From your local machine:

   ```console
   terraform destroy
   ```



Enjoy!   
