# CloudWatch Logs用のロググループ作成
resource "aws_cloudwatch_log_group" "vpn_log_group" {
  name              = "/aws/client-vpn-endpoint/vpn-logs"
  retention_in_days = 30 # ログの保持期間を30日に設定

  tags = {
    Name = "vpn-connection-logs"
  }
}

# CloudWatch Logs用のログストリーム作成
resource "aws_cloudwatch_log_stream" "vpn_log_stream" {
  name           = "vpn-connection-logs"
  log_group_name = aws_cloudwatch_log_group.vpn_log_group.name

  depends_on = [aws_cloudwatch_log_group.vpn_log_group]
}
