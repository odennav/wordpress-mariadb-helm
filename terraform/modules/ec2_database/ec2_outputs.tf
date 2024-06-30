# AWS EC2 Instance Terraform Outputs


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

