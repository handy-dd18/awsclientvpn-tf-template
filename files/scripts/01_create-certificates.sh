#!/bin/bash
set -e

# 証明書を生成するディレクトリを指定
CERT_DIR="/files/certificates"
OUTPUT_DIR="/files/certificates/output"
EASYRSA_PATH="/home/vscode/easy-rsa"

# 証明書名の設定
SERVER_NAME="server"
CLIENT_NAME="client1.domain.tld"

# 証明書ディレクトリの存在確認・作成
if [ ! -d "$CERT_DIR" ]; then
  echo "Creating certificates directory..."
  mkdir -p "$CERT_DIR"
fi

# 出力ディレクトリの存在確認・作成
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Creating output directory..."
  mkdir -p "$OUTPUT_DIR"
fi

# 必要なファイルが全て存在するか確認
REQUIRED_FILES=("$OUTPUT_DIR/ca.crt" "$OUTPUT_DIR/server.crt" "$OUTPUT_DIR/server.key" "$OUTPUT_DIR/client.crt" "$OUTPUT_DIR/client.key")
FILES_EXIST=true

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    FILES_EXIST=false
    break
  fi
done

# 全てのファイルが存在する場合、スキップするかどうか確認
if [ "$FILES_EXIST" = true ]; then
  echo "既に必要な証明書ファイルが存在します:"
  ls -la $OUTPUT_DIR
  
  # ユーザーに確認
  read -p "証明書ファイルが既に存在します。証明書の再生成をスキップしますか？ (y/n): " SKIP_GENERATION
  if [[ "$SKIP_GENERATION" =~ ^[Yy]$ ]]; then
    echo "証明書の生成をスキップします。既存の証明書を使用します。"
    
    # 既存の証明書情報の表示
    echo "サーバー証明書の情報:"
    openssl x509 -in $OUTPUT_DIR/server.crt -text -noout | grep -E "Subject:|X509v3 Subject Alternative Name:"
    
    echo "クライアント証明書の情報:"
    openssl x509 -in $OUTPUT_DIR/client.crt -text -noout | grep -E "Subject:|X509v3 Subject Alternative Name:"
    
    echo "必要な証明書ファイルは $OUTPUT_DIR に既に存在しています"
    echo "これらの証明書は機密情報です。安全に保管してください。"
    
    # ファイル一覧を表示
    echo "使用するファイル一覧:"
    ls -la $OUTPUT_DIR
    
    # ACMへのインポート方法を表示
    echo ""
    echo "次のコマンドを使用して、証明書をACMにアップロードすることができます:"
    echo "docker compose run --rm terraform apply"
    
    exit 0
  else
    echo "証明書を再生成します..."
  fi
fi

# PKIディレクトリが既に存在する場合は削除
if [ -d "$CERT_DIR/pki" ]; then
  echo "Removing existing PKI directory..."
  rm -rf "$CERT_DIR/pki"
fi

# easyrsa スクリプトの場所を確認
if [ -f "$EASYRSA_PATH/easyrsa" ]; then
  echo "Found easyrsa at $EASYRSA_PATH/easyrsa"
  EASYRSA_CMD="$EASYRSA_PATH/easyrsa"
else
  echo "easyrsa script not found at $EASYRSA_PATH/easyrsa"
  echo "Could not find easyrsa script. Please check the installation."
  exit 1
fi

# 作業ディレクトリを変更
cd $CERT_DIR

# バッチモードの設定
export EASYRSA_BATCH="yes"

# PKIの初期化
echo "Initializing PKI..."
$EASYRSA_CMD init-pki

# CAの作成
echo "Building CA..."
$EASYRSA_CMD build-ca nopass

# サーバー証明書と鍵の生成 (SANを含む)
echo "Building server certificate..."
$EASYRSA_CMD --san=DNS:server build-server-full $SERVER_NAME nopass

# クライアント証明書と鍵の生成
echo "Building client certificate..."
$EASYRSA_CMD build-client-full $CLIENT_NAME nopass

# 必要なファイルだけをoutputディレクトリにコピー
echo "Copying required files to output directory..."
if [ -d "$CERT_DIR/pki" ]; then
    cp $CERT_DIR/pki/ca.crt $OUTPUT_DIR/
    cp $CERT_DIR/pki/issued/$SERVER_NAME.crt $OUTPUT_DIR/server.crt
    cp $CERT_DIR/pki/private/$SERVER_NAME.key $OUTPUT_DIR/server.key
    cp $CERT_DIR/pki/issued/$CLIENT_NAME.crt $OUTPUT_DIR/client.crt
    cp $CERT_DIR/pki/private/$CLIENT_NAME.key $OUTPUT_DIR/client.key
    
    # 証明書情報の確認（デバッグ用）
    echo "サーバー証明書の情報:"
    openssl x509 -in $OUTPUT_DIR/server.crt -text -noout | grep -E "Subject:|X509v3 Subject Alternative Name:"
    
    echo "クライアント証明書の情報:"
    openssl x509 -in $OUTPUT_DIR/client.crt -text -noout | grep -E "Subject:|X509v3 Subject Alternative Name:"
    
    # ファイルが正常にコピーされたか確認
    if [ -f "$OUTPUT_DIR/ca.crt" ] && [ -f "$OUTPUT_DIR/server.crt" ] && [ -f "$OUTPUT_DIR/server.key" ] && [ -f "$OUTPUT_DIR/client.crt" ] && [ -f "$OUTPUT_DIR/client.key" ]; then
        echo "すべてのファイルが正常にコピーされました"
    else
        echo "警告: いくつかのファイルがコピーされませんでした"
        ls -la $OUTPUT_DIR
    fi
else
    echo "警告: PKI directory not found at expected location: $CERT_DIR/pki"
    echo "Searching for certificate files..."
    find $CERT_DIR -name "ca.crt" -exec cp {} $OUTPUT_DIR/ \;
    find $CERT_DIR -name "$SERVER_NAME.crt" -exec cp {} $OUTPUT_DIR/server.crt \;
    find $CERT_DIR -name "$SERVER_NAME.key" -exec cp {} $OUTPUT_DIR/server.key \;
    find $CERT_DIR -name "$CLIENT_NAME.crt" -exec cp {} $OUTPUT_DIR/client.crt \;
    find $CERT_DIR -name "$CLIENT_NAME.key" -exec cp {} $OUTPUT_DIR/client.key \;
fi

echo "必要な証明書ファイルは $OUTPUT_DIR に正常に出力されました"
echo "これらの証明書は機密情報です。安全に保管してください。"

# ファイル一覧を表示
echo "出力されたファイル一覧:"
ls -la $OUTPUT_DIR

# ACMへのインポート方法を表示
echo ""
echo "次のコマンドを使用して、証明書をACMにアップロードすることができます:"
echo "docker compose run --rm terraform apply"