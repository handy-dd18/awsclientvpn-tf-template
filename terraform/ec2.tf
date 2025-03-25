# 動作確認用EC2インスタンスの作成
## 不要であれば全てコメントアウトしてください

# AMIデータソース - 最新のAmazon Linux 2 AMIを取得
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      data.aws_vpc.default.cidr_block
    ]
  }

  ingress {
    from_port = -1
    to_port   = -1
    protocol  = "icmp"
    cidr_blocks = [
      data.aws_vpc.default.cidr_block
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

resource "aws_instance" "amazon_linux" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = data.aws_key_pair.keypair.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
              #!/bin/bash
              # システムアップデート
              yum update -y

              # 基本的なテストファイルの作成
              echo "Hello from Terraform provisioned instance" > /home/ec2-user/hello.txt

              # テスト用ユーザーの作成（SSHアクセス専用）
              useradd ${var.ec2_test_user}
              echo "${var.ec2_test_user}:${var.ec2_test_password}" | chpasswd
              
              # SSHアクセスの設定（パスワード認証を有効化）
              sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              systemctl restart sshd
              
              # ユーザーのホームディレクトリにSSH認証用のディレクトリを作成
              mkdir -p /home/${var.ec2_test_user}/.ssh
              
              # キーペアからの認証も使えるように設定
              if [ -f /home/ec2-user/.ssh/authorized_keys ]; then
                cp /home/ec2-user/.ssh/authorized_keys /home/${var.ec2_test_user}/.ssh/
                chown -R ${var.ec2_test_user}:${var.ec2_test_user} /home/${var.ec2_test_user}/.ssh
                chmod 700 /home/${var.ec2_test_user}/.ssh
                chmod 600 /home/${var.ec2_test_user}/.ssh/authorized_keys
              fi
              
              # テスト用のwelcomeメッセージ
              echo "Welcome to the test EC2 instance. This user is for SSH access only." > /home/${var.ec2_test_user}/welcome.txt
              chown ${var.ec2_test_user}:${var.ec2_test_user} /home/${var.ec2_test_user}/welcome.txt
              EOF


  tags = {
    Name = "amazon-linux-instance"
  }
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.amazon_linux.id
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.amazon_linux.private_ip
}

output "instance_private_dns" {
  description = "Private DNS of the EC2 instance"
  value       = aws_instance.amazon_linux.private_dns
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.amazon_linux_2.id
}

output "ami_name" {
  description = "AMI name used for the instance"
  value       = data.aws_ami.amazon_linux_2.name
}
