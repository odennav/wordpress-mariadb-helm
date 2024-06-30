## Overview of Terraform Files

#### main.tf 
- Specifies the required Terraform version and the AWS provider version.

#### generic_variables.tf
- Defines input variables such as the AWS region, environment, and business division.

#### local_values.tf
- Specifies local values used in Terraform, including owners, environment, and name.

#### vpc_variables.tf
- Utilizes input variables to provision VPC with specified configurations.

#### vpc_module.tf
- Defines a Terraform module to create the VPC with configurable parameters like VPC name, CIDR blocks, availability zones, and subnets.

#### vpc_outputs.tf
- Outputs VPC-related information such as VPC ID, CIDR blocks, subnets, NAT gateway IPs, and availability zones.

#### securitygroup_bastionsg.tf
- Creates a security group for the public bastion host.

#### securitygroup_privatesg.tf
- Creates a security group for private EC2 instances.

#### securitygroup_outputs.tf
- Outputs security group information for public bastion hosts and private EC2 instances.

#### datasource_ami.tf
- Retrieves the latest RHEL9 ID.

#### ec2instance_variables.tf
- Defines variables for EC2 instances, including type, key pair, and instance count.

#### ec2instance_bastion.tf
- Defines module for public ec2-instance

#### ec2instance_master.tf
- Defines module for master node.

#### ec2instance_outputs.tf
- Outputs information about public and private EC2 instances. Insert ip addresses for private ec2instances into ipaddr-list.txt.
list of IPs used by bash scripts for kubernetes deployment.

#### ec2instance_workers.tf
- Creates  EC2 instances for the worker nodes.

#### dbinstance_private.tf
- Creates EC2 instances for the database subnet with count specified.

#### elasticip.tf
- Creates an Elastic IP for the NAT gateway.

