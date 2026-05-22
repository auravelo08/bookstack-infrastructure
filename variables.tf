variable "region" {
  default = "eu-north-1"
}

variable "azs" {
  default = ["eu-north-1a", "eu-north-1b"]
}

variable "dev_ips" {
  type = list(string)
}

variable "keypair_name" {
  description = "SSH keypair name"
  type        = string
}

variable "ami_id" {
  description = "AMI Ubuntu 26.04"
  type        = string
}

variable "rds_master_password" {
  type        = string
  description = "Le mot de passe administrateur (dbadmin) du RDS"
  sensitive   = true # Masque le mot de passe dans les logs de la console
}

variable "project" {
  default = "bookstack"
}

variable "environment" {
  default = "prod"
}
