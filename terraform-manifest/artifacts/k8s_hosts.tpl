[k8s_master]
%{ for ip in master_ip ~}
${ip} 
%{ endfor ~}

[k8s_node]
%{ for ip in worker_ip ~}
${ip}
%{ endfor ~}


[nfs_server]
%{ for ip in nfs_ip ~}
${ip} 
%{ endfor ~}
