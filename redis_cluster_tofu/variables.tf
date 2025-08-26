
variable "redis_server_ips" {
  description = "The IP addresses of the two physical servers."
  type        = list(string)
  default     = ["192.168.227.153", "192.168.227.154", "192.168.227.155"]
}

variable "redis_port" {
  description = "The port that Redis will listen on for all nodes."
  type        = number
  default     = 6379
}

variable "ssh_user" {
  description = "SSH username for connecting to the VMs."
  type        = string
  default     = "mensyli1"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key."
  type        = string
  default     = "/home/mensyli1/.ssh/tofu_mysql_key"
}

variable "redis_password" {
  description = "Password for Redis cluster."
  type        = string
  #sensitive   = true
  default     = "xiaoming98"
}
