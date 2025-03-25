#!/bin/bash
set -e

# 変数定義
OUTPUT_DIR="/files/certificates/download"
CLIENT_CERT_DIR="/files/certificates/output"

# 出力ディレクトリの確認と作成
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "ダウンロードディレクトリの作成..."
  mkdir -p "$OUTPUT_DIR"
fi

echo "AWS Client VPN設定ファイルをダウンロードしています..."

# Terraformの状態からClient VPN Endpoint IDを取得
# ワークスペースのマウント位置に合わせてパスを修正
if [ -d "/workspace" ]; then
  TERRAFORM_DIR="/workspace"
elif [ -d "/terraform" ]; then
  TERRAFORM_DIR="/terraform"
else
  # 現在のディレクトリから相対パスで検索
  for possible_dir in "/files/../terraform" "../terraform" "../../terraform"; do
    if [ -d "$possible_dir" ]; then
      TERRAFORM_DIR="$possible_dir"
      break
    fi
  done

  # それでも見つからない場合
  if [ -z "$TERRAFORM_DIR" ]; then
    echo "エラー: Terraformディレクトリが見つかりません。"
    echo "現在の場所: $(pwd)"
    echo "利用可能なディレクトリ:"
    ls -la /
    exit 1
  fi
fi

echo "Terraformディレクトリを使用: $TERRAFORM_DIR"
cd "$TERRAFORM_DIR"

# Terraformの状態からEndpoint IDを取得
ENDPOINT_ID=$(terraform output -raw client_vpn_endpoint_id)

if [ -z "$ENDPOINT_ID" ]; then
  echo "エラー: Client VPN Endpoint IDが見つかりません。terraform applyが正常に実行されているか確認してください。"
  exit 1
fi

echo "Client VPN Endpoint ID: $ENDPOINT_ID"

# AWS CLIを使用してクライアント設定ファイルをダウンロード
CONFIG_FILE="$OUTPUT_DIR/downloaded-client-config.ovpn"
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id $ENDPOINT_ID \
  --output text > $CONFIG_FILE

if [ $? -ne 0 ]; then
  echo "エラー: クライアント設定ファイルのダウンロードに失敗しました。"
  exit 1
fi

echo "クライアント設定ファイルのダウンロードに成功しました: .$CONFIG_FILE"

# クライアント証明書と鍵の内容を取得
CLIENT_CERT_CONTENT=""
CLIENT_KEY_CONTENT=""

if [ -f "$CLIENT_CERT_DIR/client.crt" ]; then
  CLIENT_CERT_CONTENT=$(cat "$CLIENT_CERT_DIR/client.crt")
else
  echo "警告: クライアント証明書ファイルが見つかりません: $CLIENT_CERT_DIR/client.crt"
fi

if [ -f "$CLIENT_CERT_DIR/client.key" ]; then
  CLIENT_KEY_CONTENT=$(cat "$CLIENT_CERT_DIR/client.key")
else
  echo "警告: クライアント鍵ファイルが見つかりません: $CLIENT_CERT_DIR/client.key"
fi

# 証明書と鍵を設定ファイルに追加
if [ -n "$CLIENT_CERT_CONTENT" ] && [ -n "$CLIENT_KEY_CONTENT" ]; then
  # 証明書と鍵のタグを追加
  echo "" >> $CONFIG_FILE
  echo "<cert>" >> $CONFIG_FILE
  echo "$CLIENT_CERT_CONTENT" >> $CONFIG_FILE
  echo "</cert>" >> $CONFIG_FILE
  echo "" >> $CONFIG_FILE
  echo "<key>" >> $CONFIG_FILE
  echo "$CLIENT_KEY_CONTENT" >> $CONFIG_FILE
  echo "</key>" >> $CONFIG_FILE
  echo "" >> $CONFIG_FILE
  
  # 追加設定
  echo "reneg-sec 0" >> $CONFIG_FILE
  echo "" >> $CONFIG_FILE
  echo "verify-x509-name server name" >> $CONFIG_FILE
  
  echo "クライアント証明書と鍵を設定ファイルに埋め込みました。"
else
  echo "警告: 証明書または鍵が見つからないため、設定ファイルに追加できませんでした。"
fi

echo ""
echo "設定ファイルは以下の場所にあります:"
echo ".$CONFIG_FILE"
echo ""
echo "AWSクライアントVPNに接続するには、このファイルをOpenVPNクライアントにインポートしてください。"
echo "注意: この設定ファイルには機密情報が含まれています。"