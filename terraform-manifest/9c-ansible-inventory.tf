
resource "local_file" "ansible_inventory" {
    content = templatefile("../artifacts/k8s_hosts.tpl",
    {
        master_ip = values(module.ec2_master)[*].private_ip
        worker_ip = values(module.ec2_workers)[*].private_ip
        nfs_ip = values(module.ec2_private_db)[*].private_ip

    })
    filename = "../../ansible/inventory"
}
