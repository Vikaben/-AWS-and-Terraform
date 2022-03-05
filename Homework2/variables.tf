variable "private_subnet" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "route_tables_names" {
  type    = list(string)
  default = ["public", "private-1", "private-2"]
}

  
variable "aws_region" {
  default = "us-east-1"
  type    = string
}
