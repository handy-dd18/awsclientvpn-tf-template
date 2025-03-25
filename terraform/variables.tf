variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_id" {
  description = "Client VPNを関連付ける既存のVPC ID"
  type        = string
}

variable "private_subnet_id" {
  description = "Client VPNを関連付けるSubnet ID"
  type        = string
}

variable "keypair_name" {
  description = "EC2に関連付けるキーペア名"
  type        = string
}

variable "ec2_test_user" {
  description = "EC2に作成するテストユーザー名"
  type        = string
}
