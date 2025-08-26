# main.tf

resource "null_resource" "redis_nodes_setup" {
  for_each = toset(var.redis_server_ips)

  triggers = {
    ssh_user             = var.ssh_user
    ssh_private_key_path = var.ssh_private_key_path
    host                 = each.value
    script_sha1          = sha1(file("${path.module}/install_redis.sh.tpl"))
  }

  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    private_key = file(pathexpand(self.triggers.ssh_private_key_path))
    host        = self.triggers.host
  }

  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/install_redis.sh.tpl", {
        port           = var.redis_port,
        redis_password = var.redis_password
      })
    ]
  }


provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo '--- Uninstalling Redis completely from ${self.triggers.host} ---'",
      "sudo systemctl stop redis-server || true",
      "sudo apt-get purge -y redis-server redis-tools || true",
      
      "sudo rm -rf /var/lib/redis/*",
      "sudo rm -f /etc/redis/redis.conf",
      "sudo rm -f /etc/redis/nodes-*.conf",
      "sudo rm -rf /var/log/redis/*",
      
      "echo '--- Cleanup complete ---'"
    ]
  }

}

resource "null_resource" "redis_cluster_create" {
  depends_on = [null_resource.redis_nodes_setup]

  triggers = {
    nodes_list = join(" ", var.redis_server_ips)
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = var.redis_server_ips[0]
  }

  provisioner "remote-exec" {
    # on_failure = continue
    inline = [
      
      "echo '--- Starting Health Check for all Redis nodes ---'",
      "for IP in ${join(" ", var.redis_server_ips)}; do",
      "  echo \"Checking node $IP:${var.redis_port}...\";",
      "  for i in {1..12}; do",
      "    if redis-cli -h $IP -p ${var.redis_port} -a '${var.redis_password}' PING; then",
      "      echo \"Node $IP is ready.\";",
      "      break;",
      "    else",
      "      echo \"Node $IP not ready yet, waiting 5 seconds... (Attempt $i/12)\";",
      "      sleep 5;",
      "    fi;",
      "    if [ $i -eq 12 ]; then echo \"Error: Node $IP timed out.\"; exit 1; fi;", 
      "  done;",
      "done;",
      "echo '--- Health Check Passed: All nodes are ready! ---'",      "ALL_NODES='${join(" ", [for ip in var.redis_server_ips : "${ip}:${var.redis_port}"])}'",
      
      "ALL_NODES='${join(" ", [for ip in var.redis_server_ips : "${ip}:${var.redis_port}"])}'",
      "echo \"Attempting to create cluster with nodes: $ALL_NODES\"",
      "echo 'yes' | sudo redis-cli -a '${var.redis_password}' --cluster create $ALL_NODES --cluster-replicas 0",
      
      "echo 'Cluster creation command sent.'",
      "sleep 10", 
      "echo 'Checking final cluster status:'",
      "sudo redis-cli -a '${var.redis_password}' -p ${var.redis_port} cluster nodes" 
    
     ]
  }
}
