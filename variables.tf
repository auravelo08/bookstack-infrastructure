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