terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

# AWS EC2 Instance Terraform Module
# EC2 Instances that will be created in VPC Private Subnets

module "ec2_private_db" {
  depends_on = [ module.vpc ] 
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.0"
  
  #name                   = "${var.environment}-vm"
  #ami                    = data.aws_ami.amzlinux2.id
  ami                     = data.aws_ami.ubuntu_22_04.id
  #ami                    = "ami-0fe630eb857a6ec83"
  
  instance_type          = var.instance_type
  key_name               = var.instance_keypair

  #user_data = file("${path.module}/install_arrival")
  
  tags = local.common_tags


  vpc_security_group_ids = [module.private_sg.security_group_id]
  for_each = toset(["1"])
  subnet_id =  element(module.vpc.database_subnets, tonumber(each.key))

  name = "db-${each.key}"
}

