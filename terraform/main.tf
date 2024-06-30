# Terraform Block

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

module "vpc" {
  source = "./modules/vpc"
}

output "vpc" {
  description = "id of virtual private cloud"
  value = module.vpc.vpc_id
}

module "security_group" {
  source = "./modules/security_group"
}

output "public_security_group" {
  description = "id of bastion security group"
  value = module.security_group.public_bastion_sg_group_id
}

output "private_security_group" {
  description = "id of private security group"
  value = module.security_group.private_sg_group_id
}

module "ec2_public" {
  source = "./modules/ec2_public"
}

output "ec2_public_id" {
  description = "id of ec2_bastion machine"
  value = module.ec2_public.ec2_bastion_public_instance_ids
}

output "ec2_public_ip" {
  description = "ec2_bastion machine ipv4 address"
  value = module.ec2_public.ec2_bastion_public_ip
}

module "ec2_kubernetes" {
  source = "./modules/ec2_kubernetes"
}

output "ec2_kubernetes_master_id" {
  description = "id of k8smaster machine"
  value = module.ec2_kubernetes.ec2_master_instance_id
}

output "ec2_kubernetes_master_ip" {
  description = "k8smaster machine ipv4 address"
  value = module.ec2_kubernetes.ec2_master_ip
}

output "ec2_kubernetes_workers_id" {
  description = "id of k8snode machines"
  value = module.ec2_kubernetes.ec2_workers_instance_id
}

output "ec2_kubernetes_workers_ip" {
  description = "k8snode machines ipv4 addresses"
  value = module.ec2_kubernetes.ec2_workers_ip
}

module "ec2_database" {
  source = "./modules/ec2_database"
}

output "ec2_database_id" {
  description = "id of ec2_db machines"
  value = module.ec2_database.ec2_private_db_instance_ids
}

output "ec2_database_ip" {
  description = "ec2_db machines ipv4 address"
  value = module.ec2_database.ec2_private_db_ip
}

