# ローカルの証明書ファイルパス
locals {
  certificate_dir = "/files/certificates/output"

  # 証明書ファイルパス
  ca_cert_file     = "${local.certificate_dir}/ca.crt"
  server_cert_file = "${local.certificate_dir}/server.crt"
  server_key_file  = "${local.certificate_dir}/server.key"
  client_cert_file = "${local.certificate_dir}/client.crt"
  client_key_file  = "${local.certificate_dir}/client.key"
}

# サーバー証明書のACMへのインポート
resource "aws_acm_certificate" "server_cert" {
  private_key       = file(local.server_key_file)
  certificate_body  = file(local.server_cert_file)
  certificate_chain = file(local.ca_cert_file)

  tags = {
    Name        = "awsclient-server-cert"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# クライアント証明書のACMへのインポート
resource "aws_acm_certificate" "client_cert" {
  private_key       = file(local.client_key_file)
  certificate_body  = file(local.client_cert_file)
  certificate_chain = file(local.ca_cert_file)

  tags = {
    Name        = "awsclient-client-cert"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 出力値の定義
output "server_certificate_arn" {
  description = "ARN of the server certificate in ACM"
  value       = aws_acm_certificate.server_cert.arn
}

output "client_certificate_arn" {
  description = "ARN of the client certificate in ACM"
  value       = aws_acm_certificate.client_cert.arn
}
