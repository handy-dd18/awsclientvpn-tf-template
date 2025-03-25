data "aws_vpc" "default" {
  id = var.vpc_id
}

data "aws_subnet" "private" {
  id = var.private_subnet_id
}

data "aws_key_pair" "keypair" {
  key_name = var.keypair_name
}
