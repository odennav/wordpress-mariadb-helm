terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}


resource "local_file" "ansible_inventory" {
    content = templatefile("../../artifacts/inventory_hosts.tpl",
    {
        master_ip = values(module.ec2_master)[*].private_ip
        worker_ip = values(module.ec2_workers)[*].private_ip
        nfs_ip = values(module.ec2_private_db)[*].private_ip

    })
    filename = "../../../inventory"
}

output "master_ips" {
    value = "${formatlist("%v - %v", ec2_master.*.private_ip, ec2_master.*.name)}"
}

output "worker_ips" {
    value = "${formatlist("%v - %v", ec2_worker.*.private_ip, ec2_worker.*.name)}"
}

output "nfs_ips" {
    value = "${formatlist("%v - %v", ec2_private_db.*.private_ip, ec2_private_db.*.name)}"
}

