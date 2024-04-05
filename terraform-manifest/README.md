## Overview of Terraform Files

### 1a-versions.tf: 
- Specifies the required Terraform version and the AWS provider version.

### 1b-generic-variables.tf:
- Defines input variables such as the AWS region, environment, and business division.

### 1c-local-values.tf:
- Specifies local values used in Terraform, including owners, environment, and name.

### 2a-vpc-variables.tf:
- Utilizes input variables to provision VPC with specified configurations.

### 2b-vpc-module.tf:
- Defines a Terraform module to create the VPC with configurable parameters like VPC name, CIDR blocks, availability zones, and subnets.

### 2c-vpc-outputs.tf:
- Outputs VPC-related information such as VPC ID, CIDR blocks, subnets, NAT gateway IPs, and availability zones.

### 3b-securitygroup-bastionsg.tf:
- Creates a security group for the public bastion host.

### 3c-securitygroup-privatesg.tf:
- Creates a security group for private EC2 instances.

### 3d-securitygroup-outputs.tf:
- Outputs security group information for public bastion hosts and private EC2 instances.

### 4-datasource-ami.tf:
- Retrieves the latest Amazon Linux 2 AMI ID.

### 5a-ec2instance-variables.tf:
- Defines variables for EC2 instances, including type, key pair, and instance count.

### 5b-ec2instance-bastion.tf:
- Defines module for public ec2-instance

### 5c-ec2instance-private.tf:
- Defines module for private ec2-instance

### 5d-ec2instance-outputs.tf:
- Outputs information about public and private EC2 instances. Insert ip addresses for private ec2instances into ipaddr-list.txt.
list of IPs used by bash scripts for kubernetes deployment.

### 5b-ec2instance-bastion.tf:
- Creates an EC2 instance for the public bastion host.

### 5c-ec2instnce-private.tf:
- Creates EC2 instances for the private subnet with count specified.

### 6-dbinstance-private.tf:
- Creates EC2 instances for the database subnet with count specified.

### 7-elasticip.tf:
- Creates an Elastic IP for the NAT gateway.

