# AWS EC2 Instance Terraform Module
# EC2 Instances that will be created in VPC Private Subnets
module "ec2_private" {
  depends_on = [ module.vpc ] # VERY VERY IMPORTANT else provisioning of private instances will fail
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.0"

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  user_data = file("${path.module}/arrival_install")
  vpc_security_group_ids = [module.private_sg.security_group_id]
  for_each = toset(["1", "2", "3"])
  subnet_id =  element(module.vpc.private_subnets, tonumber(each.key))
  name = "k8snode-${each.key}"
  tags = local.common_tags

  #instance_count         = var.private_instance_count
  #subnet_ids = [module.vpc.private_subnets[0],module.vpc.private_subnets[1] ]
}


