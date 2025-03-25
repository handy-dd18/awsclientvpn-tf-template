# Client VPN Endpoint定義
resource "aws_ec2_client_vpn_endpoint" "vpn" {
  description            = "client vpn endpoint test"
  server_certificate_arn = aws_acm_certificate.server_cert.arn
  client_cidr_block      = "100.0.0.0/16"
  split_tunnel           = true
  transport_protocol     = "tcp"

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_cert.arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn_log_group.name
    cloudwatch_log_stream = "vpn-connection-logs" # 固定のログストリーム名を設定
  }

  tags = {
    Name = "vpn"
  }

  depends_on = [aws_cloudwatch_log_group.vpn_log_group]
}

# Client VPN Network Association定義
resource "aws_ec2_client_vpn_network_association" "vpn" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = data.aws_subnet.private.id

  depends_on = [aws_ec2_client_vpn_endpoint.vpn]
}

# Client VPN Authorization Rule定義
resource "aws_ec2_client_vpn_authorization_rule" "vpn" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = data.aws_subnet.private.cidr_block
  authorize_all_groups   = true

  depends_on = [aws_ec2_client_vpn_endpoint.vpn]
}

output "client_vpn_endpoint_id" {
  description = "Client VPN Endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.vpn.id
}
