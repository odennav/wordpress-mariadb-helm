# AWS EC2 Instance Terraform Outputs

# Public EC2 Instances - Bastion Host
## ec2_bastion_public_instance_ids
output "ec2_bastion_public_instance_ids" {
  description = "EC2 instance ID"
  value       = module.ec2_public.id
}

## ec2_bastion_public_ip
output "ec2_bastion_public_ip" {
  description = "Public IP address EC2 instance"
  value       = module.ec2_public.public_ip 
}

# Private EC2 Master Instance
## ec2_master_instance_id
output "ec2_master_instance_ids" {
  description = "List of IDs of instances"
  value = [for ec2master in module.ec2_master: ec2master.id ]   
}

## ec2_master_ip
output "ec2_master_ip" {
  description = "List of private IP addresses assigned to the instances"
  value = [for ec2master in module.ec2_master: ec2master.private_ip ]  
}


# Private EC2 Workers Instances
## ec2_workers_instance_id
output "ec2_workers_instance_ids" {
  description = "List of IDs of instances"
  value = [for ec2worker in module.ec2_workers: ec2workers.id ]
}

## ec2_workers_ip
output "ec2_workers_ip" {
  description = "List of private IP addresses assigned to the instances"
  value = [for ec2worker in module.ec2_workers: ec2workers.private_ip ]
}



# Private EC2_DB Instances
## ec2_private_db_instance_ids
output "ec2_private_db_instance_ids" {
  description = "List of IDs of instances"
  value = [for ec2private_db in module.ec2_private_db: ec2private_db.id ]
}

## ec2_private_db_ip
output "ec2_private_db_ip" {
  description = "List of private IP addresses assigned to the instances"
  value = [for ec2private_db in module.ec2_private_db: ec2private_db.private_ip ]
}




