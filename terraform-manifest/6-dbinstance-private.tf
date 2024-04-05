# AWS EC2 Instance Terraform Module
# EC2 Instances that will be created in VPC Private Subnets
module "ec2_private_db" {
  depends_on = [ module.vpc ] # VERY VERY IMPORTANT else userdata webserver provisioning will fail
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.0"
  # insert the 10 required variables here
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair

  #user_data = file("${path.module}/install_arrival")
  
  tags = local.common_tags


# Changes as of Module version UPGRADE from 2.17.0 to 5.5.0
  vpc_security_group_ids = [module.private_sg.security_group_id]
  for_each = toset(["1"])
  subnet_id =  element(module.vpc.database_subnets, tonumber(each.key))

  name = "db-${each.key}"
}


# ELEMENT Function
# terraform console 
# element(["kalyan", "reddy", "daida"], 0)
# element(["kalyan", "reddy", "daida"], 1)
# element(["kalyan", "reddy", "daida"], 2)

