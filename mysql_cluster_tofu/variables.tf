# variables.tf

variable "master_ip" {
  description = "IP address of the MySQL Master node"
  type        = string
  default     = "192.168.227.153"
}

variable "slave_ips" {
  description = "List of IP addresses for the MySQL Slave nodes"
  type        = list(string)
  default     = ["192.168.227.154", "192.168.227.155"]
}

variable "ssh_user" {
  description = "SSH username for connecting to the VMs"
  type        = string
  default     = "mensyli1"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default     = "/home/mensyli1/.ssh/tofu_mysql_key"
}

variable "mysql_root_password" {
  description = "The root password for MySQL"
  type        = string
  #sensitive   = true
  default     = "xiaoming98"
}

variable "mysql_repl_user" {
  description = "The user for MySQL replication"
  type        = string
  default     = "mensyli1"
}

variable "mysql_repl_password" {
  description = "The password for the replication user"
  type        = string
  #sensitive   = true
  default     = "xiaoming98" 
}
