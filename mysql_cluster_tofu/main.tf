# main.tf

resource "null_resource" "mysql_master" {
  triggers = {
    ssh_user             = var.ssh_user
    ssh_private_key_path = var.ssh_private_key_path
    host                 = var.master_ip
    always_run           = timestamp() 
  }

  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    private_key = file(pathexpand(self.triggers.ssh_private_key_path))
    host        = self.triggers.host
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server",

      "sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${var.mysql_root_password}';\"",
    
      "sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf",
      "if ! grep -q '^server-id' /etc/mysql/mysql.conf.d/mysqld.cnf; then sudo sed -i '/^#server-id/a server-id              = 1' /etc/mysql/mysql.conf.d/mysqld.cnf; fi",
      "if ! grep -q '^log_bin' /etc/mysql/mysql.conf.d/mysqld.cnf; then sudo sed -i '/^server-id/a log_bin                 = /var/log/mysql/mysql-bin.log' /etc/mysql/mysql.conf.d/mysqld.cnf; fi",
      "sudo systemctl restart mysql",
      "until mysqladmin ping -h 127.0.0.1 --silent; do echo 'Waiting for mysql...'; sleep 2; done",
      
      "sudo mysql -u root -p'${var.mysql_root_password}' -e \"CREATE USER IF NOT EXISTS '${var.mysql_repl_user}'@'%' IDENTIFIED WITH mysql_native_password BY '${var.mysql_repl_password}';\"",
      "sudo mysql -u root -p'${var.mysql_root_password}' -e \"ALTER USER '${var.mysql_repl_user}'@'%' IDENTIFIED WITH mysql_native_password BY '${var.mysql_repl_password}';\"",
      "sudo mysql -u root -p'${var.mysql_root_password}' -e \"GRANT REPLICATION SLAVE ON *.* TO '${var.mysql_repl_user}'@'%';\"",
      "sudo mysql -u root -p'${var.mysql_root_password}' -e \"GRANT REPLICATION SLAVE ON *.* TO '${var.mysql_repl_user}'@'%';\"",
      "sudo mysql -u root -p'${var.mysql_root_password}' -e \"FLUSH PRIVILEGES;\""  
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo 'Uninstalling MySQL from master...'",
      "sudo systemctl stop mysql || true",
      "sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* || true",
      "sudo rm -rf /var/lib/mysql || true",
      "sudo apt-get autoremove -y || true",
      "sudo apt-get clean"
    ]
  }
}


data "external" "master_status" {
  depends_on = [null_resource.mysql_master]

  program = [
    "bash",
    "-c",
    templatefile("${path.module}/get_master_status.sh", {
      private_key_path    = pathexpand(var.ssh_private_key_path),
      ssh_user            = var.ssh_user,
      master_ip           = var.master_ip,
      mysql_root_password = var.mysql_root_password
    })
  ]
}

resource "null_resource" "mysql_slaves" {
  depends_on = [data.external.master_status]

  for_each = toset(var.slave_ips)

  triggers = {
    ssh_user             = var.ssh_user
    ssh_private_key_path = var.ssh_private_key_path
    host                 = each.value
    always_run           = timestamp()
  }

  connection {
    type        = "ssh"
    user        = self.triggers.ssh_user
    private_key = file(pathexpand(self.triggers.ssh_private_key_path))
    host        = self.triggers.host
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server",

      "sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${var.mysql_root_password}';\"",

      "sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf",

      "SERVER_ID=$(echo ${self.triggers.host} | cut -d . -f 4)",
      "sudo sed -i '/^\\s*#\\?server-id/d' /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo sed -i '/^\\[mysqld\\]/a server-id              = '$SERVER_ID /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo systemctl restart mysql",
      "until mysqladmin ping -h 127.0.0.1 --silent; do echo 'Waiting for mysql on slave...'; sleep 2; done",
      "sudo mysql -u root -p'${var.mysql_root_password}' -e \"STOP SLAVE; CHANGE MASTER TO MASTER_HOST='${var.master_ip}', MASTER_USER='${var.mysql_repl_user}', MASTER_PASSWORD='${var.mysql_repl_password}', MASTER_LOG_FILE='${data.external.master_status.result.log_file}', MASTER_LOG_POS=${data.external.master_status.result.log_pos}; START SLAVE;\"",
      "until mysqladmin ping -h 127.0.0.1 --silent; do echo 'Waiting for mysql...'; sleep 2; done",
      "echo 'Checking slave status on ${self.triggers.host}:'",
      "sudo mysql -u root -p'${var.mysql_root_password}' -e 'SHOW SLAVE STATUS\\G' | grep -E 'Slave_IO_Running|Slave_SQL_Running'"
    ]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "echo 'Uninstalling MySQL from slave: ${self.triggers.host}'",
      "sudo systemctl stop mysql || true",
      "sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* || true",
      "sudo rm -rf /var/lib/mysql || true",
      "sudo apt-get autoremove -y || true",
      "sudo apt-get clean"
    ]
  }
}
